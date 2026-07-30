import type { PolicyState, Preferences, ShareState, Statistics } from '../core/types'
import {
  focus,
  hasFocusShortcuts,
  nativeAutoLaunch,
  notifications,
  screenSharing,
  watchScreenSharing,
} from '@stacksjs/desktop/browser'
import { describe, evaluate, toggleManually } from '../core/policy'
import {
  DEFAULT_PREFERENCES,
  normalizePreferences,
  parsePreferences,
  serializePreferences,
} from '../core/preferences'
import {
  emptyStatistics,
  parseStatistics,
  recordActivation,
  recordDeactivation,
  serializeStatistics,
} from '../core/statistics'
import { initialPolicyState } from '../core/types'
import { readDocument, writeDocument } from './storage'

const PREFERENCES_FILE = 'preferences.json'
const STATISTICS_FILE = 'statistics.json'

/** Everything the UI renders from. */
export interface HushState {
  prefs: Preferences
  stats: Statistics
  share: ShareState
  /** Focus is on because of Hush. */
  engaged: boolean
  /** One-line description of what's happening. */
  status: string
  /**
   * Whether both Focus shortcuts exist. Until they do, Hush can observe
   * sharing but cannot act on it, and the UI says so instead of failing
   * silently at the moment a meeting starts.
   */
  shortcutsReady: boolean
}

export type StateListener = (state: HushState) => void

const IDLE_SHARE: ShareState = { sharing: false, sources: [] }

export class HushController {
  private prefs: Preferences = { ...DEFAULT_PREFERENCES }
  private stats: Statistics = emptyStatistics(Date.now())
  private share: ShareState = IDLE_SHARE
  private policy: PolicyState = initialPolicyState()
  private shortcutsReady = false
  private listeners = new Set<StateListener>()
  private stopWatching: (() => void) | null = null

  /**
   * Load persisted state, verify the Focus shortcuts, and start watching.
   *
   * Detection starts even when the shortcuts are missing: the status the UI
   * shows is more useful when it reflects reality, and the user may add the
   * shortcuts while the app is running.
   */
  async start(): Promise<void> {
    const now = Date.now()
    const [prefsText, statsText] = await Promise.all([
      readDocument(PREFERENCES_FILE),
      readDocument(STATISTICS_FILE),
    ])
    this.prefs = parsePreferences(prefsText)
    this.stats = parseStatistics(statsText, now)

    await this.refreshShortcuts()
    await this.syncLaunchAtLogin()

    this.share = await screenSharing.getState()
    this.stopWatching = await watchScreenSharing(
      state => void this.onShareChange(state),
      this.prefs.detectionIntervalMs,
    )
    this.emit()
  }

  async stop(): Promise<void> {
    this.stopWatching?.()
    this.stopWatching = null
  }

  subscribe(listener: StateListener): () => void {
    this.listeners.add(listener)
    listener(this.snapshot())
    return () => this.listeners.delete(listener)
  }

  snapshot(): HushState {
    return {
      prefs: { ...this.prefs },
      stats: { ...this.stats },
      share: { sharing: this.share.sharing, sources: [...this.share.sources] },
      engaged: this.policy.engaged,
      status: describe(this.share.sharing, this.share.sources, this.policy.engaged),
      shortcutsReady: this.shortcutsReady,
    }
  }

  /** Update preferences, persist them, and re-apply anything they affect. */
  async updatePreferences(patch: Partial<Preferences>): Promise<void> {
    const next = normalizePreferences({ ...this.prefs, ...patch })
    const intervalChanged = next.detectionIntervalMs !== this.prefs.detectionIntervalMs
    const launchChanged = next.launchAtLogin !== this.prefs.launchAtLogin
    const shortcutsChanged
      = next.focusOnShortcut !== this.prefs.focusOnShortcut
        || next.focusOffShortcut !== this.prefs.focusOffShortcut

    this.prefs = next
    await writeDocument(PREFERENCES_FILE, serializePreferences(next))

    if (launchChanged) await this.syncLaunchAtLogin()
    if (shortcutsChanged) await this.refreshShortcuts()
    if (intervalChanged) await screenSharing.watch(next.detectionIntervalMs)

    // A preference change can make the current signal actionable — turning
    // automatic activation on mid-share, for instance — so re-run the policy
    // rather than waiting for the next poll.
    await this.applyPolicy()
    this.emit()
  }

  /** Toggle Focus from the menu. Immediate, and takes ownership either way. */
  async toggleFocus(enabled: boolean): Promise<void> {
    const { action, state } = toggleManually(this.policy, enabled)
    this.policy = state
    await this.perform(action, true)
    this.emit()
  }

  /** Re-check whether the Focus shortcuts exist, e.g. after setup. */
  async refreshShortcuts(): Promise<boolean> {
    this.shortcutsReady = await hasFocusShortcuts(
      this.prefs.focusOnShortcut,
      this.prefs.focusOffShortcut,
    )
    return this.shortcutsReady
  }

  private async onShareChange(state: ShareState): Promise<void> {
    this.share = state
    await this.applyPolicy()
    this.emit()
  }

  private async applyPolicy(): Promise<void> {
    const { action, state } = evaluate(this.share.sharing, this.prefs, this.policy, Date.now())
    this.policy = state
    await this.perform(action, false)
  }

  /**
   * Carry out a policy decision.
   *
   * If the Shortcut fails — most often because it was renamed or deleted —
   * ownership is rolled back so the next evaluation retries rather than
   * believing a Focus is engaged that never turned on.
   */
  private async perform(action: 'enable' | 'disable' | 'none', manual: boolean): Promise<void> {
    if (action === 'none') return

    const enabling = action === 'enable'
    const result = await focus.setEnabled(enabling, {
      onShortcut: this.prefs.focusOnShortcut,
      offShortcut: this.prefs.focusOffShortcut,
    })

    if (!result.ok) {
      this.policy = { engaged: !enabling, pending: null }
      this.shortcutsReady = false
      await this.notify(
        'Hush could not change Focus',
        result.error || 'Check that the Focus shortcuts still exist in Shortcuts.',
      )
      return
    }

    const now = Date.now()
    this.stats = enabling
      ? recordActivation(this.stats, now, manual)
      : recordDeactivation(this.stats, now, manual)
    await writeDocument(STATISTICS_FILE, serializeStatistics(this.stats))

    await this.notify(
      enabling ? 'Focus on' : 'Focus off',
      enabling ? describe(this.share.sharing, this.share.sources, true) : 'Notifications are back.',
    )
  }

  private async notify(title: string, body: string): Promise<void> {
    if (!this.prefs.showNotifications) return
    try {
      await notifications.show({ title, body })
    }
    catch {
      // A notification that cannot be posted is never worth interrupting
      // detection for.
    }
  }

  /**
   * Reconcile the login item with the preference.
   *
   * The system is the source of truth: a user who removed Hush from Login
   * Items in System Settings should not have it silently re-added, so a
   * matching state is left alone.
   */
  private async syncLaunchAtLogin(): Promise<void> {
    try {
      const isEnabled = await nativeAutoLaunch.isEnabled()
      if (isEnabled === this.prefs.launchAtLogin) return
      if (this.prefs.launchAtLogin) await nativeAutoLaunch.enable()
      else await nativeAutoLaunch.disable()
    }
    catch {
      // Login-item registration is not available outside a packaged bundle.
    }
  }

  private emit(): void {
    const state = this.snapshot()
    for (const listener of this.listeners) listener(state)
  }
}

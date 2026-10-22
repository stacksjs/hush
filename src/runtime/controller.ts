import type { PolicyState, Preferences, ShareState, Statistics } from '../core/types'
import { backgroundDelay, focus, nativeAutoLaunch, notifications, permissions, screenSharing, watchScreenSharing } from '@stacksjs/desktop/browser'
import { describe, evaluate, toggleManually } from '../core/policy'
import { DEFAULT_PREFERENCES, normalizePreferences, parsePreferences, serializePreferences } from '../core/preferences'
import { emptyStatistics, parseStatistics, recordActivation, recordDeactivation, serializeStatistics } from '../core/statistics'
import { initialPolicyState } from '../core/types'
import { readDocument, writeDocument } from './storage'

const PREFERENCES_FILE = 'preferences.json'
const STATISTICS_FILE = 'statistics.json'

/** Everything the UI renders from. */
export interface HushState {
  focusStatusReadable: boolean
  prefs: Preferences
  stats: Statistics
  share: ShareState
  /** Focus is on because of Hush. */
  engaged: boolean
  /** A sharing transition is still waiting for its configured delay. */
  transitionPending: boolean
  /** One-line description of what's happening. */
  status: string
  /**
   * Whether both Focus shortcuts exist. Until they do, Hush can observe
   * sharing but cannot act on it, and the UI says so instead of failing
   * silently at the moment a meeting starts.
   *
   * `unknown` inside the App Sandbox, where enumerating shortcuts is not
   * possible. Nagging a user who has already done the setup is worse than
   * saying nothing, so `unknown` shows no prompt.
   */
  shortcutsReady: boolean | 'unknown'
  /**
   * Screen Recording permission, which macOS requires before it will report
   * window titles. Without it the conference and recording signals cannot
   * fire, and Hush can only see system screen sharing.
   */
  screenRecording: PermissionStatus
  /** Optional Accessibility access for native browser and conferencing sharing controls. */
  accessibility: PermissionStatus
}

/** Mirrors the desktop package's status values. */
export type PermissionStatus = 'granted' | 'denied' | 'restricted' | 'undetermined' | 'not-supported'

export type StateListener = (state: HushState) => void

const IDLE_SHARE: ShareState = { sharing: false, sources: [] }

export class HushController {
  private prefs: Preferences = { ...DEFAULT_PREFERENCES }
  private stats: Statistics = emptyStatistics(Date.now())
  private share: ShareState = IDLE_SHARE
  private policy: PolicyState = initialPolicyState()
  private shortcutsReady: boolean | 'unknown' = 'unknown'
  private focusStatusReadable = false
  private screenRecording: PermissionStatus = 'undetermined'
  private accessibility: PermissionStatus = 'undetermined'
  private listeners = new Set<StateListener>()
  private stopWatching: (() => void | Promise<void>) | null = null
  private transitionTimer: AbortController | null = null
  private transitionError: string | null = null
  private operations: Promise<unknown> = Promise.resolve()
  private started = false
  private starting: Promise<void> | null = null
  private stopped = false

  private enqueue<T>(operation: () => Promise<T>): Promise<T> {
    const result = this.operations.then(operation)
    this.operations = result.catch(() => { this.emit() })
    return result
  }

  private cancelTransition(): void {
    this.transitionTimer?.abort()
    this.transitionTimer = null
  }

  /**
   * Load persisted state, verify the Focus shortcuts, and start watching.
   *
   * Detection starts even when the shortcuts are missing: the status the UI
   * shows is more useful when it reflects reality, and the user may add the
   * shortcuts while the app is running.
   */
  start(): Promise<void> {
    if (this.starting) return this.starting
    if (this.started) return Promise.resolve()
    this.stopped = false
    this.starting = this.enqueue(() => this.initialize()).catch((error) => {
      this.started = false
      throw error
    }).finally(() => { this.starting = null })
    return this.starting
  }

  private async initialize(): Promise<void> {
    const now = Date.now()
    const [prefsText, statsText] = await Promise.all([
      readDocument(PREFERENCES_FILE),
      readDocument(STATISTICS_FILE),
    ])
    this.prefs = parsePreferences(prefsText)
    this.stats = parseStatistics(statsText, now)

    await this.checkShortcuts()
    await this.refreshScreenRecording()
    this.accessibility = await permissions.check('accessibility')
    await this.refreshFocusStatus()
    // Respect Login Items changes made in System Settings. Only an explicit
    // preference edit below may register or unregister the item.
    this.prefs.launchAtLogin = await nativeAutoLaunch.isEnabled()

    this.share = await screenSharing.getState()
    this.started = true
    this.stopWatching = await watchScreenSharing(
      state => void this.onShareChange(state),
      this.prefs.detectionIntervalMs,
    )
    await this.applyPolicy()
    this.emit()
  }

  stop(): Promise<void> {
    this.stopped = true
    this.cancelTransition()
    return this.enqueue(async () => {
      await this.stopWatching?.()
      this.stopWatching = null
      this.started = false
      this.policy = { ...this.policy, pending: null }
      if (this.policy.engaged && !this.prefs.keepEnabledAfterSharing) {
        await this.perform('disable', false)
        if (this.policy.engaged) throw new Error('Hush could not release Focus. Retry before quitting.')
      }
      this.emit()
    })
  }

  subscribe(listener: StateListener): () => void {
    this.listeners.add(listener)
    listener(this.snapshot())
    return () => this.listeners.delete(listener)
  }

  snapshot(): HushState {
    return {
      focusStatusReadable: this.focusStatusReadable,
      prefs: { ...this.prefs },
      stats: { ...this.stats },
      share: { sharing: this.share.sharing, sources: [...this.share.sources] },
      engaged: this.policy.engaged,
      transitionPending: this.policy.pending !== null,
      status: this.transitionError || describe(this.share.sharing, this.share.sources, this.policy.engaged),
      shortcutsReady: this.shortcutsReady,
      screenRecording: this.screenRecording,
      accessibility: this.accessibility,
    }
  }

  /** Update preferences, persist them, and re-apply anything they affect. */
  updatePreferences(patch: Partial<Preferences>): Promise<void> {
    return this.enqueue(() => this.changePreferences(patch))
  }

  private async changePreferences(patch: Partial<Preferences>): Promise<void> {
    const next = normalizePreferences({ ...this.prefs, ...patch })
    const intervalChanged = next.detectionIntervalMs !== this.prefs.detectionIntervalMs
    const launchChanged = next.launchAtLogin !== this.prefs.launchAtLogin
    const shortcutsChanged = next.focusOnShortcut !== this.prefs.focusOnShortcut
      || next.focusOffShortcut !== this.prefs.focusOffShortcut

    this.prefs = next
    if (!await writeDocument(PREFERENCES_FILE, serializePreferences(next)))
      throw new Error('Hush could not save preferences. Check access to Application Support.')

    if (launchChanged) await this.syncLaunchAtLogin()
    if (shortcutsChanged) await this.checkShortcuts()
    if (intervalChanged) await screenSharing.watch(next.detectionIntervalMs)

    // A preference change can make the current signal actionable — turning
    // automatic activation on mid-share, for instance — so re-run the policy
    // rather than waiting for the next poll.
    await this.applyPolicy()
    this.emit()
  }

  /** Toggle Focus from the menu. Immediate, and takes ownership either way. */
  toggleFocus(enabled: boolean): Promise<void> {
    return this.enqueue(async () => {
      this.cancelTransition()
      const { action } = toggleManually(this.policy, enabled)
      this.policy = { ...this.policy, pending: null }
      await this.perform(action, true)
      this.emit()
    })
  }

  /**
   * Re-check whether the Focus shortcuts exist, e.g. after setup.
   *
   * Returns `'unknown'` where enumeration is impossible rather than guessing.
   */
  refreshShortcuts(): Promise<boolean | 'unknown'> {
    return this.enqueue(async () => {
      const ready = await this.checkShortcuts()
      await this.applyPolicy()
      this.emit()
      return ready
    })
  }

  private async checkShortcuts(): Promise<boolean | 'unknown'> {
    const result = await focus.listShortcutsResult()
    this.shortcutsReady = result.canList
      ? result.shortcuts.includes(this.prefs.focusOnShortcut)
      && result.shortcuts.includes(this.prefs.focusOffShortcut)
      : 'unknown'
    return this.shortcutsReady
  }

  /**
   * Re-read the Screen Recording grant.
   *
   * Conference detection reads window titles, which macOS withholds without
   * this permission — so without it Hush silently degrades to system
   * screen-sharing only. The UI says so rather than looking broken.
   */
  async refreshScreenRecording(): Promise<PermissionStatus> {
    this.screenRecording = await permissions.check('screen_recording')
    return this.screenRecording
  }

  private async refreshFocusStatus(): Promise<void> {
    const status = await focus.getStatus()
    this.focusStatusReadable = status?.supported === true && status.authorization === 'authorized' && status.isFocused !== null
  }

  /** Permission is requested from the explicit setup button, never at boot. */
  requestFocusAuthorization(): Promise<void> {
    return this.enqueue(async () => {
      await focus.requestAuthorization()
      await this.refreshFocusStatus()
      await this.applyPolicy()
      this.emit()
    })
  }

  /** Ask for Screen Recording, or send the user to System Settings. */
  async requestScreenRecording(): Promise<PermissionStatus> {
    this.screenRecording = await permissions.request('screen_recording')
    // If macOS still reports access unavailable, open the matching Privacy
    // pane for this explicit setup action. Do not retry from the watcher.
    if (this.screenRecording !== 'granted') await permissions.openSettings('screen_recording')
    this.emit()
    return this.screenRecording
  }

  /** Tab-capture detection uses the public, permission-gated native AX API. */
  async requestAccessibility(): Promise<PermissionStatus> {
    this.accessibility = await permissions.request('accessibility')
    if (this.accessibility !== 'granted') await permissions.openSettings('accessibility')
    this.emit()
    return this.accessibility
  }

  private onShareChange(state: ShareState): Promise<void> {
    return this.enqueue(async () => {
      if (this.stopped) return
      this.share = state
      await this.applyPolicy()
      this.emit()
    })
  }

  private async applyPolicy(): Promise<void> {
    this.cancelTransition()
    if (this.stopped) return
    this.transitionError = null
    const { action, state } = evaluate(this.share.sharing, this.prefs, this.policy, Date.now())
    // An in-flight Shortcut has not changed Focus yet. Publish ownership only
    // after it succeeds, and serialize all edits through the same queue.
    this.policy = { ...state, engaged: this.policy.engaged }
    await this.perform(action, false)
    const pending = this.policy.pending
    if (pending && !this.stopped) {
      const delay = pending.target ? this.prefs.activationDelayMs : this.prefs.deactivationDelayMs
      const timer = new AbortController()
      this.transitionTimer = timer
      this.transitionError = null
      void backgroundDelay(Math.max(0, pending.since + delay - Date.now()), { signal: timer.signal }).then(() => {
        if (this.transitionTimer !== timer) return
        return this.enqueue(async () => {
          if (this.transitionTimer !== timer) return
          await this.applyPolicy()
          this.emit()
        })
      }).catch((error: unknown) => {
        if (timer.signal.aborted) return
        this.transitionError = `Hush could not schedule Focus: ${error instanceof Error ? error.message : String(error)}`
        this.emit()
      })
    }
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
    if (enabling && !manual) {
      if (this.shortcutsReady === false) return
      const current = await focus.getStatus()
      // A Focus the user already enabled belongs to them. Do not replace it
      // with Do Not Disturb or later clear it when sharing ends.
      this.focusStatusReadable = current?.supported === true && current.authorization === 'authorized' && current.isFocused !== null
      if (!this.focusStatusReadable || current.isFocused === true) return
    }
    let result
    try {
      result = await focus.setEnabled(enabling, {
        onShortcut: this.prefs.focusOnShortcut,
        offShortcut: this.prefs.focusOffShortcut,
      })
    }
    catch (error) {
      result = { ok: false, error: error instanceof Error ? error.message : String(error) }
    }

    if (!result.ok) {
      this.policy = { engaged: !enabling, pending: null }
      // A failed run is direct evidence the shortcut is not usable, which is
      // worth more than an enumeration we may not be allowed to perform.
      this.shortcutsReady = false
      await this.notify(
        'Hush could not change Focus',
        result.error || 'Check that the Focus shortcuts still exist in Shortcuts.',
      )
      return
    }

    this.policy = { engaged: enabling, pending: null }
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
    const requested = this.prefs.launchAtLogin
    const current = await nativeAutoLaunch.isEnabled()
    if (current === requested) return
    const changed = requested ? await nativeAutoLaunch.enable() : await nativeAutoLaunch.disable()
    if (!changed) {
      this.prefs.launchAtLogin = await nativeAutoLaunch.isEnabled()
      await writeDocument(PREFERENCES_FILE, serializePreferences(this.prefs))
      throw new Error('macOS could not change Launch at Login. Check Login Items in System Settings.')
    }
  }

  private emit(): void {
    const state = this.snapshot()
    for (const listener of this.listeners) listener(state)
  }
}

import { mockBackgroundDelay } from '../test-utils/background-delay'
import { afterEach, beforeEach, describe, expect, it } from 'bun:test'
import { findCall, installMockBridge } from '@stacksjs/desktop/test-utils'
import { DEFAULT_PREFERENCES } from '../src/core/preferences'
import { HushController } from '../src/runtime/controller'
import { resetStorageCache } from '../src/runtime/storage'

/**
 * Controller behaviour against a mocked Craft bridge.
 *
 * These cover the wiring the pure tests can't: that a share actually reaches
 * the Shortcut, that a failed Shortcut doesn't leave Hush believing Focus is
 * on, and that preferences survive a restart.
 */

const SHARING = {
  sharing: true,
  signals: { systemScreenShare: false, remoteSession: false, conferenceSharing: true, screenRecording: false },
  sources: [{ app: 'zoom.us', window: 'as_toolbar', kind: 'conference' }],
}

const IDLE = {
  sharing: false,
  signals: { systemScreenShare: false, remoteSession: false, conferenceSharing: false, screenRecording: false },
  sources: [],
}

/** In-memory stand-in for the Application Support directory. */
function installFakeFs(bridge: ReturnType<typeof installMockBridge>): Map<string, string> {
  const files = new Map<string, string>()
  bridge.whenCalled('shell', 'getEnv', () => '/Users/test')
  bridge.whenCalled('fs', 'exists', (path: unknown) => files.has(String(path)))
  bridge.whenCalled('fs', 'readFile', (path: unknown) => ({ data: files.get(String(path)) ?? '' }))
  bridge.whenCalled('fs', 'writeFile', (path: unknown, data: unknown) => {
    files.set(String(path), String(data))
  })
  bridge.whenCalled('fs', 'mkdir', () => undefined)
  return files
}

function emitShare(state: unknown): void {
  window.dispatchEvent(new CustomEvent('craft:screenSharing:change', { detail: state }))
}

/** Let the controller's async change handler settle. */
async function settle(): Promise<void> {
  for (let i = 0; i < 40; i++) await Promise.resolve()
}

describe('HushController', () => {
  let bridge: ReturnType<typeof installMockBridge>
  let files: Map<string, string>

  beforeEach(() => {
    resetStorageCache()
    bridge = installMockBridge(['fs', 'shell', 'focus', 'screenSharing', 'notifications', 'autoLaunch', 'permissions', 'timers'])
    bridge.whenCalled('timers', 'sleep', mockBackgroundDelay)
    files = installFakeFs(bridge)
    bridge.whenCalled('screenSharing', 'getState', () => IDLE)
    bridge.whenCalled('screenSharing', 'watch', () => ({ ok: true, intervalMs: 2000 }))
    bridge.whenCalled('screenSharing', 'unwatch', () => ({ ok: true }))
    bridge.whenCalled('focus', 'getStatus', () => ({ supported: true, authorization: 'authorized', isFocused: false }))
    bridge.whenCalled('focus', 'listShortcuts', () => ['Hush Focus On', 'Hush Focus Off'])
    bridge.whenCalled('focus', 'listShortcutsResult', () => ({ canList: true, shortcuts: ['Hush Focus On', 'Hush Focus Off'] }))
    bridge.whenCalled('permissions', 'check', () => 'granted')
    bridge.whenCalled('permissions', 'request', () => 'granted')
    bridge.whenCalled('permissions', 'openSettings', () => undefined)
    bridge.whenCalled('focus', 'setEnabled', { ok: true, strategy: 'shortcut', exitCode: 0 })
    bridge.whenCalled('notifications', 'show', () => undefined)
    bridge.whenCalled('autoLaunch', 'isEnabled', () => false)
  })

  afterEach(() => {
    bridge.uninstall()
  })

  it('surfaces native scheduling failures instead of silently missing Focus', async () => {
    bridge.whenCalled('timers', 'sleep', (_ms: number, _options: unknown) => Promise.reject(new Error('Native deadline unavailable')))
    const controller = new HushController()
    await controller.start()
    emitShare(SHARING)
    await settle()
    expect(controller.snapshot().status).toContain('Native deadline unavailable')
    expect(controller.snapshot().engaged).toBe(false)
    await controller.stop()
  })

  it('cancels pending native work on stop and ignores a late completion', async () => {
    const pending: { signal?: AbortSignal, complete?: () => void } = {}
    bridge.whenCalled('timers', 'sleep', (_ms: number, options: { signal: AbortSignal }) => {
      pending.signal = options.signal
      return new Promise<void>(resolve => { pending.complete = resolve })
    })
    const controller = new HushController()
    await controller.start()
    emitShare(SHARING)
    await settle()
    expect(pending.signal?.aborted).toBe(false)
    expect(controller.snapshot().transitionPending).toBe(true)
    await controller.stop()
    expect(pending.signal?.aborted).toBe(true)
    expect(controller.snapshot().transitionPending).toBe(false)
    pending.complete?.()
    await settle()
    expect(controller.snapshot().engaged).toBe(false)
    expect(findCall(bridge.calls, 'focus', 'setEnabled')).toBeUndefined()
  })

  it('starts with defaults on a clean install', async () => {
    const c = new HushController()
    await c.start()
    const state = c.snapshot()
    expect(state.prefs).toEqual(DEFAULT_PREFERENCES)
    expect(state.stats.sessions).toBe(0)
    expect(state.engaged).toBe(false)
    expect(state.shortcutsReady).toBe(true)
    await c.stop()
  })

  it('reports setup as incomplete when a shortcut is missing', async () => {
    bridge.whenCalled('focus', 'listShortcutsResult', () => ({ canList: true, shortcuts: ['Hush Focus On'] }))
    const c = new HushController()
    await c.start()
    expect(c.snapshot().shortcutsReady).toBe(false)
    await c.stop()
  })

  it('still watches for sharing when the shortcuts are missing', async () => {
    // The status is more useful when it reflects reality, and the user may add
    // the shortcuts while Hush is running.
    bridge.whenCalled('focus', 'listShortcutsResult', () => ({ canList: true, shortcuts: [] }))
    const c = new HushController()
    await c.start()
    emitShare(SHARING)
    await settle()
    expect(c.snapshot().share.sharing).toBe(true)
    expect(c.snapshot().status).toBe('Sharing in zoom.us')
    await c.stop()
  })

  it('engages Focus once a share settles, and records the session', async () => {
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ activationDelayMs: 0 })

    emitShare(SHARING)
    await settle()

    const state = c.snapshot()
    expect(state.engaged).toBe(true)
    expect(state.stats.sessions).toBe(1)
    expect(state.status).toBe('Sharing in zoom.us')
    await c.stop()
  })

  it('rolls ownership back when the Shortcut fails', async () => {
    bridge.whenCalled('focus', 'setEnabled', () => ({ ok: false, exitCode: 1, error: 'shortcut not found' }))
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ activationDelayMs: 0 })

    emitShare(SHARING)
    await settle()

    const state = c.snapshot()
    // Believing Focus is on when it isn't would mean never retrying, and
    // never turning it "off" again either.
    expect(state.engaged).toBe(false)
    expect(state.stats.sessions).toBe(0)
    expect(state.shortcutsReady).toBe(false)
    await c.stop()
  })

  it('releases Focus when the share ends', async () => {
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ activationDelayMs: 0, deactivationDelayMs: 0 })

    emitShare(SHARING)
    await settle()
    emitShare(IDLE)
    await settle()

    const state = c.snapshot()
    expect(state.engaged).toBe(false)
    expect(state.stats.lastDeactivatedAt).not.toBeNull()
    await c.stop()
  })

  it('honours keep-enabled-after-sharing', async () => {
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ activationDelayMs: 0, deactivationDelayMs: 0, keepEnabledAfterSharing: true })

    emitShare(SHARING)
    await settle()
    emitShare(IDLE)
    await settle()

    expect(c.snapshot().engaged).toBe(true)
    await c.stop()
  })

  it('re-checking installed shortcuts makes an unchanged share actionable', async () => {
    bridge.whenCalled('focus', 'listShortcutsResult', () => ({ canList: true, shortcuts: [] }))
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ activationDelayMs: 0 })
    emitShare(SHARING)
    await settle()
    expect(findCall(bridge.calls, 'focus', 'setEnabled')).toBeUndefined()
    bridge.whenCalled('focus', 'listShortcutsResult', () => ({ canList: true, shortcuts: ['Hush Focus On', 'Hush Focus Off'] }))
    await c.refreshShortcuts()
    expect(c.snapshot().engaged).toBe(true)
    await c.stop()
  })

  it('settles activation and deactivation after a single native change event', async () => {
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ activationDelayMs: 20, deactivationDelayMs: 30 })
    emitShare(SHARING)
    await settle()
    expect(c.snapshot().engaged).toBe(false)
    await Bun.sleep(40)
    expect(c.snapshot().engaged).toBe(true)
    emitShare(IDLE)
    await settle()
    await Bun.sleep(50)
    expect(c.snapshot().engaged).toBe(false)
    await c.stop()
  })

  it('cancels a pending activation when the share ends or the app stops', async () => {
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ activationDelayMs: 20 })
    emitShare(SHARING)
    await settle()
    emitShare(IDLE)
    await settle()
    await Bun.sleep(40)
    expect(findCall(bridge.calls, 'focus', 'setEnabled')).toBeUndefined()
    emitShare(SHARING)
    await settle()
    await c.stop()
    await Bun.sleep(40)
    expect(findCall(bridge.calls, 'focus', 'setEnabled')).toBeUndefined()
  })

  it('does not take ownership of a Focus the user already enabled', async () => {
    bridge.whenCalled('focus', 'getStatus', () => ({ supported: true, authorization: 'authorized', isFocused: true }))
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ activationDelayMs: 0, deactivationDelayMs: 0 })
    emitShare(SHARING)
    await settle()
    emitShare(IDLE)
    await settle()
    expect(findCall(bridge.calls, 'focus', 'setEnabled')).toBeUndefined()
    expect(c.snapshot().engaged).toBe(false)
    await c.stop()
  })

  it('waits for readable Focus status instead of overriding an unknown Focus', async () => {
    // macOS can return false even before permission has been granted.
    bridge.whenCalled('focus', 'getStatus', () => ({ supported: true, authorization: 'notDetermined', isFocused: false }))
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ activationDelayMs: 0 })
    emitShare(SHARING)
    await settle()
    expect(findCall(bridge.calls, 'focus', 'setEnabled')).toBeUndefined()
    expect(c.snapshot().focusStatusReadable).toBe(false)
    bridge.whenCalled('focus', 'requestAuthorization', () => 'authorized')
    bridge.whenCalled('focus', 'getStatus', () => ({ supported: true, authorization: 'authorized', isFocused: false }))
    await c.requestFocusAuthorization()
    expect(c.snapshot().engaged).toBe(true)
    await c.stop()
  })

  it('serializes opposing Focus requests and publishes only completed changes', async () => {
    const c = new HushController()
    await c.start()
    let finish: (result: { ok: boolean }) => void = () => {}
    bridge.whenCalled('focus', 'setEnabled', () => new Promise(resolve => { finish = resolve }))
    const enabling = c.toggleFocus(true)
    await settle()
    expect(c.snapshot().engaged).toBe(false)
    const disabling = c.toggleFocus(false)
    await settle()
    expect(bridge.calls.filter(call => call.ns === 'focus' && call.method === 'setEnabled')).toHaveLength(1)
    bridge.whenCalled('focus', 'setEnabled', () => ({ ok: true }))
    finish({ ok: true })
    await Promise.all([enabling, disabling])
    expect(c.snapshot().engaged).toBe(false)
    expect(c.snapshot().stats.sessions).toBe(1)
    await c.stop()
  })

  it('reconciles Login Items from macOS without silently re-registering', async () => {
    files.set('/Users/test/Library/Application Support/Hush/preferences.json', JSON.stringify({ launchAtLogin: true }))
    const c = new HushController()
    await c.start()
    expect(c.snapshot().prefs.launchAtLogin).toBe(false)
    expect(findCall(bridge.calls, 'autoLaunch', 'enable')).toBeUndefined()
    await c.stop()
  })

  it('corrects a failed Login Items change instead of claiming it was enabled', async () => {
    bridge.whenCalled('autoLaunch', 'enable', () => false)
    const c = new HushController()
    await c.start()
    await expect(c.updatePreferences({ launchAtLogin: true })).rejects.toThrow('macOS could not change')
    expect(c.snapshot().prefs.launchAtLogin).toBe(false)
    expect(JSON.parse([...files.values()][0]!).launchAtLogin).toBe(false)
    await c.stop()
  })

  it('releases owned Focus before completing shutdown', async () => {
    const c = new HushController()
    await c.start()
    await c.toggleFocus(true)
    await c.stop()
    expect(c.snapshot().engaged).toBe(false)
    expect(bridge.calls.filter(call => call.ns === 'focus' && call.method === 'setEnabled').map(call => call.args[0])).toEqual([true, false])
  })

  it('persists preferences across a restart', async () => {
    const first = new HushController()
    await first.start()
    await first.updatePreferences({ keepEnabledAfterSharing: true, deactivationDelayMs: 9000 })
    await first.stop()

    expect([...files.keys()].some(k => k.endsWith('preferences.json'))).toBe(true)

    const second = new HushController()
    await second.start()
    const prefs = second.snapshot().prefs
    expect(prefs.keepEnabledAfterSharing).toBe(true)
    expect(prefs.deactivationDelayMs).toBe(9000)
    await second.stop()
  })

  it('clamps an out-of-range preference rather than accepting it', async () => {
    const c = new HushController()
    await c.start()
    await c.updatePreferences({ detectionIntervalMs: 5 })
    expect(c.snapshot().prefs.detectionIntervalMs).toBe(250)
    await c.stop()
  })

  it('notifies subscribers immediately on subscribe', async () => {
    const c = new HushController()
    await c.start()
    let seen = 0
    const off = c.subscribe(() => { seen++ })
    expect(seen).toBe(1)
    off()
    await c.stop()
  })

  it('reports setup as unknown when the sandbox cannot enumerate shortcuts', async () => {
    // An empty list there would read as "no shortcuts installed" and push a
    // user who finished setup back through it.
    bridge.whenCalled('focus', 'listShortcutsResult', () => ({ canList: false, shortcuts: [] }))
    const c = new HushController()
    await c.start()
    expect(c.snapshot().shortcutsReady).toBe('unknown')
    await c.stop()
  })

  it('reads the Screen Recording grant on start', async () => {
    bridge.whenCalled('permissions', 'check', () => 'denied')
    const c = new HushController()
    await c.start()
    expect(c.snapshot().screenRecording).toBe('denied')
    await c.stop()
  })

  it('opens System Settings when the native Screen Recording request remains denied', async () => {
    bridge.whenCalled('permissions', 'check', () => 'denied')
    bridge.whenCalled('permissions', 'request', () => 'denied')
    const c = new HushController()
    await c.start()
    await c.requestScreenRecording()
    expect(findCall(bridge.calls, 'permissions', 'request')).toBeDefined()
    expect(findCall(bridge.calls, 'permissions', 'openSettings')).toBeDefined()
    await c.stop()
  })

  it('requests Accessibility only after the explicit setup action', async () => {
    bridge.whenCalled('permissions', 'check', (name: unknown) => name === 'accessibility' ? 'denied' : 'granted')
    bridge.whenCalled('permissions', 'request', (name: unknown) => {
      expect(name).toBe('accessibility')
      return 'denied'
    })
    bridge.whenCalled('permissions', 'openSettings', (name: unknown) => {
      expect(name).toBe('accessibility')
    })
    const c = new HushController()
    await c.start()
    expect(c.snapshot().accessibility).toBe('denied')
    expect(findCall(bridge.calls, 'permissions', 'request')).toBeUndefined()
    await c.requestAccessibility()
    expect(findCall(bridge.calls, 'permissions', 'request')?.args).toEqual(['accessibility'])
    expect(findCall(bridge.calls, 'permissions', 'openSettings')?.args).toEqual(['accessibility'])
    await c.stop()
  })

  it('a manual toggle takes effect without waiting for a share', async () => {
    const c = new HushController()
    await c.start()
    await c.toggleFocus(true)
    expect(c.snapshot().engaged).toBe(true)
    expect(c.snapshot().stats.manualToggles).toBe(1)
    await c.stop()
  })
})

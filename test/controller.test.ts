import { afterEach, beforeEach, describe, expect, it } from 'bun:test'
import { installMockBridge } from '@stacksjs/desktop/test-utils'
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
  for (let i = 0; i < 8; i++) await Promise.resolve()
}

describe('HushController', () => {
  let bridge: ReturnType<typeof installMockBridge>
  let files: Map<string, string>

  beforeEach(() => {
    resetStorageCache()
    bridge = installMockBridge(['fs', 'shell', 'focus', 'screenSharing', 'notifications', 'autoLaunch'])
    files = installFakeFs(bridge)
    bridge.whenCalled('screenSharing', 'getState', () => IDLE)
    bridge.whenCalled('screenSharing', 'watch', () => ({ ok: true, intervalMs: 2000 }))
    bridge.whenCalled('screenSharing', 'unwatch', () => ({ ok: true }))
    bridge.whenCalled('focus', 'listShortcuts', () => ['Hush Focus On', 'Hush Focus Off'])
    bridge.whenCalled('focus', 'setEnabled', () => ({ ok: true, strategy: 'shortcut', exitCode: 0 }))
    bridge.whenCalled('notifications', 'show', () => undefined)
    bridge.whenCalled('autoLaunch', 'isEnabled', () => false)
  })

  afterEach(() => {
    bridge.uninstall()
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
    bridge.whenCalled('focus', 'listShortcuts', () => ['Hush Focus On'])
    const c = new HushController()
    await c.start()
    expect(c.snapshot().shortcutsReady).toBe(false)
    await c.stop()
  })

  it('still watches for sharing when the shortcuts are missing', async () => {
    // The status is more useful when it reflects reality, and the user may add
    // the shortcuts while Hush is running.
    bridge.whenCalled('focus', 'listShortcuts', () => [])
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

  it('a manual toggle takes effect without waiting for a share', async () => {
    const c = new HushController()
    await c.start()
    await c.toggleFocus(true)
    expect(c.snapshot().engaged).toBe(true)
    expect(c.snapshot().stats.manualToggles).toBe(1)
    await c.stop()
  })
})

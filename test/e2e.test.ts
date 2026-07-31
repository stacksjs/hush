import { afterEach, beforeEach, describe, expect, it } from 'bun:test'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { Window } from 'very-happy-dom'

/**
 * End-to-end against the artifact that actually ships.
 *
 * Not the source — `dist/Hush.app/Contents/Resources/index.html`, the compiled
 * document with the real client bundle inlined. The unit tests cover the
 * controller against a mocked bridge; what they cannot catch is the template
 * and the bundle disagreeing: an id renamed in one and not the other, a
 * handler bound to an element that no longer exists, a build that silently
 * emitted the fallback source instead of a bundle. Every one of those produces
 * a green unit suite and an app that does nothing when you click it.
 *
 * Run `bun run build` first. The test skips with a clear message otherwise
 * rather than passing vacuously.
 */

const BUNDLE_PATH = join(import.meta.dir, '..', 'dist', 'Hush.app', 'Contents', 'Resources', 'index.html')

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

interface Harness {
  window: any
  document: any
  calls: Array<{ ns: string, method: string, args: unknown[] }>
  files: Map<string, string>
  responses: Map<string, (...args: any[]) => unknown>
  text: (id: string) => string
  checked: (id: string) => boolean
  hidden: (id: string) => boolean
  click: (id: string) => void
  emitShare: (state: unknown) => void
  settle: () => Promise<void>
}

/**
 * Load the built document into a DOM, install a mock Craft bridge, and run the
 * client bundle against it — the same order WebKit does inside a Craft window.
 */
function boot(overrides: Record<string, (...args: any[]) => unknown> = {}): Harness {
  const html = readFileSync(BUNDLE_PATH, 'utf8')

  const window = new Window() as any
  const document = window.document
  document.write(html)

  const calls: Harness['calls'] = []
  const files = new Map<string, string>()
  const responses = new Map<string, (...args: any[]) => unknown>()

  // The bridge Craft injects, standing in for the native side. Auto-vivifies
  // namespaces so the bundle can reach any `craft.<ns>.<method>` it likes.
  window.craft = new Proxy({}, {
    get: (_t: unknown, ns: string) => new Proxy({}, {
      get: (_t2: unknown, method: string) => (...args: unknown[]) => {
        calls.push({ ns, method, args })
        const handler = responses.get(`${ns}:${method}`)
        return Promise.resolve(handler ? handler(...args) : undefined)
      },
    }),
  })

  responses.set('shell:getEnv', () => '/Users/test')
  responses.set('fs:exists', (path: string) => files.has(String(path)))
  responses.set('fs:readFile', (path: string) => ({ data: files.get(String(path)) ?? '' }))
  responses.set('fs:writeFile', (path: string, data: string) => { files.set(String(path), String(data)) })
  responses.set('fs:mkdir', () => undefined)
  responses.set('focus:listShortcuts', () => ['Hush Focus On', 'Hush Focus Off'])
  responses.set('focus:setEnabled', () => ({ ok: true, strategy: 'shortcut', exitCode: 0 }))
  responses.set('screenSharing:getState', () => IDLE)
  responses.set('screenSharing:watch', () => ({ ok: true, intervalMs: 2000 }))
  responses.set('screenSharing:unwatch', () => ({ ok: true }))
  responses.set('notifications:show', () => undefined)
  responses.set('autoLaunch:isEnabled', () => false)

  // Applied before the bundle runs, so a test that needs a different native
  // answer gets it on the very first call rather than racing the boot sequence.
  for (const [key, handler] of Object.entries(overrides)) responses.set(key, handler)

  // Run only the app's own bundle. The stx router and the Craft component
  // runtime are not what this test is about, and executing them adds noise
  // without adding coverage.
  const bundle = html.match(/<script data-stx-scoped>([\s\S]*?)<\/script>/)?.[1]
  if (!bundle) throw new Error('No client bundle in the built document — the build emitted no <script data-stx-scoped>')
  // A bundle that still contains a bare `import` means stx fell back to the
  // raw source instead of bundling; that is a SyntaxError in a real webview.
  if (/^\s*import\s/m.test(bundle)) throw new Error('Client bundle contains an unresolved import — stx fell back to raw source')

  // Execute with the DOM's globals bound as parameters — the bundle is an
  // IIFE, so this is the same scope WebKit gives an inline <script>.
  // eslint-disable-next-line no-new-func
  const run = new Function('window', 'document', 'CustomEvent', 'Event', bundle)
  run(window, document, window.CustomEvent, window.Event)

  const el = (id: string) => document.getElementById(id)

  return {
    window,
    document,
    calls,
    files,
    responses,
    text: id => (el(id)?.textContent ?? '').trim(),
    checked: id => Boolean(el(id)?.checked),
    hidden: id => Boolean(el(id)?.hidden),
    click: (id) => {
      const node = el(id)
      if (!node) throw new Error(`No element #${id} in the built document`)
      if (node.tagName === 'INPUT') node.checked = !node.checked
      node.dispatchEvent(new window.Event(node.tagName === 'INPUT' ? 'change' : 'click', { bubbles: true }))
    },
    emitShare: state => window.dispatchEvent(new window.CustomEvent('craft:screenSharing:change', { detail: state })),
    settle: async () => { for (let i = 0; i < 20; i++) await Promise.resolve() },
  }
}

function findCall(calls: Harness['calls'], ns: string, method: string) {
  return calls.find(c => c.ns === ns && c.method === method)
}

const built = existsSync(BUNDLE_PATH)
const suite = built ? describe : describe.skip

if (!built) {
  // eslint-disable-next-line no-console
  console.warn(`e2e: no built app at ${BUNDLE_PATH} — run \`bun run build\` first. Skipping.`)
}

suite('Hush end to end (built bundle in a DOM)', () => {
  let h: Harness

  beforeEach(async () => {
    h = boot()
    await h.settle()
  })

  afterEach(() => {
    h.window.close?.()
  })

  it('every control the bundle binds to exists in the document', () => {
    // The failure this catches is an id renamed on one side only, which leaves
    // a control that looks fine and does nothing.
    for (const id of [
      'app',
      'status',
      'focus-state',
      'sources',
      'setup',
      'recheck-shortcuts',
      'toggle-focus',
      'pref-automatic',
      'pref-keep',
      'pref-notify',
      'pref-login',
      'stat-sessions',
      'stat-total',
      'stat-average',
      'quit',
    ]) {
      expect(h.document.getElementById(id)).not.toBeNull()
    }
  })

  it('renders the idle state on boot', async () => {
    expect(h.text('status')).toBe('Not sharing')
    expect(h.text('focus-state')).toBe('Focus is off')
    expect(h.checked('toggle-focus')).toBe(false)
    expect(h.hidden('sources')).toBe(true)
  })

  it('hides the setup panel when both shortcuts are installed', async () => {
    expect(h.hidden('setup')).toBe(true)
  })

  it('shows the setup panel and its instructions when a shortcut is missing', async () => {
    h = boot({ 'focus:listShortcuts': () => ['Hush Focus On'] })
    await h.settle()
    expect(h.hidden('setup')).toBe(false)
    expect(h.text('setup')).toContain('Hush Focus On')
    expect(h.text('setup')).toContain('Set Focus')
  })

  it('reflects preference defaults in the checkboxes', async () => {
    expect(h.checked('pref-automatic')).toBe(true)
    expect(h.checked('pref-keep')).toBe(false)
    expect(h.checked('pref-notify')).toBe(true)
    expect(h.checked('pref-login')).toBe(false)
  })

  it('renders statistics rather than the placeholder', async () => {
    expect(h.text('stat-sessions')).toBe('0')
    expect(h.text('stat-total')).toBe('0s')
    expect(h.text('stat-average')).toBe('0s')
  })

  it('reacts to a share starting: status, sources, dot state and Focus', async () => {
    h.emitShare(SHARING)
    await h.settle()
    // The activation delay is 1s by default, so nothing should have fired yet.
    expect(findCall(h.calls, 'focus', 'setEnabled')).toBeUndefined()
    expect(h.text('status')).toBe('Sharing in zoom.us')
    expect(h.document.getElementById('app').dataset.sharing).toBe('true')
    expect(h.hidden('sources')).toBe(false)
    expect(h.text('sources')).toContain('zoom.us')
    expect(h.text('sources')).toContain('as_toolbar')

    // A second sample past the delay is what settles the transition.
    h.emitShare(SHARING)
    await h.settle()
    await new Promise(r => setTimeout(r, 1100))
    h.emitShare(SHARING)
    await h.settle()

    const call = findCall(h.calls, 'focus', 'setEnabled')
    expect(call).toBeDefined()
    expect(call!.args[0]).toBe(true)
    expect(h.text('focus-state')).toBe('Focus is on')
    expect(h.checked('toggle-focus')).toBe(true)
    expect(h.document.getElementById('app').dataset.engaged).toBe('true')
  })

  it('counts the session and shows it in the statistics panel', async () => {
    h.emitShare(SHARING)
    await h.settle()
    await new Promise(r => setTimeout(r, 1100))
    h.emitShare(SHARING)
    await h.settle()
    expect(h.text('stat-sessions')).toBe('1')
  })

  it('clears back to idle when the share ends', async () => {
    h.emitShare(SHARING)
    await h.settle()
    h.emitShare(IDLE)
    await h.settle()
    expect(h.text('status')).toBe('Not sharing')
    expect(h.document.getElementById('app').dataset.sharing).toBe('false')
    expect(h.hidden('sources')).toBe(true)
  })

  it('toggling Focus by hand drives the bridge and updates the UI', async () => {
    h.click('toggle-focus')
    await h.settle()

    const call = findCall(h.calls, 'focus', 'setEnabled')
    expect(call).toBeDefined()
    expect(call!.args[0]).toBe(true)
    expect(h.text('focus-state')).toBe('Focus is on')
    expect(h.text('stat-sessions')).toBe('1')
  })

  it('changing a preference persists it and keeps the checkbox in sync', async () => {
    h.click('pref-keep')
    await h.settle()

    expect(h.checked('pref-keep')).toBe(true)
    const written = [...h.files.entries()].find(([k]) => k.endsWith('preferences.json'))
    expect(written).toBeDefined()
    expect(JSON.parse(written![1]).keepEnabledAfterSharing).toBe(true)
  })

  it('turning off automatic activation stops a share from engaging Focus', async () => {
    h.click('pref-automatic')
    await h.settle()
    expect(h.checked('pref-automatic')).toBe(false)

    h.emitShare(SHARING)
    await h.settle()
    await new Promise(r => setTimeout(r, 1100))
    h.emitShare(SHARING)
    await h.settle()

    expect(findCall(h.calls, 'focus', 'setEnabled')).toBeUndefined()
    expect(h.text('focus-state')).toBe('Focus is off')
  })

  it('the re-check button asks the bridge again', async () => {
    const before = h.calls.filter(c => c.ns === 'focus' && c.method === 'listShortcuts').length
    h.click('recheck-shortcuts')
    await h.settle()
    const after = h.calls.filter(c => c.ns === 'focus' && c.method === 'listShortcuts').length
    expect(after).toBeGreaterThan(before)
  })

  it('quit stops watching before it quits', async () => {
    h.click('quit')
    await h.settle()
    expect(findCall(h.calls, 'screenSharing', 'unwatch')).toBeDefined()
    expect(findCall(h.calls, 'app', 'quit')).toBeDefined()
  })

  it('surfaces a failed Shortcut instead of claiming Focus is on', async () => {
    h = boot({ 'focus:setEnabled': () => ({ ok: false, exitCode: 1, error: 'shortcut not found' }) })
    await h.settle()

    h.click('toggle-focus')
    await h.settle()

    expect(h.text('focus-state')).toBe('Focus is off')
    expect(h.checked('toggle-focus')).toBe(false)
    // Setup guidance comes back, because a missing shortcut is what this
    // almost always means.
    expect(h.hidden('setup')).toBe(false)
  })
})

import type { HushState } from '../runtime/controller'
import { app } from '@stacksjs/desktop/browser'
import { averageSessionSeconds, formatDuration } from '../core/statistics'
import { HushController } from '../runtime/controller'

/**
 * Bind the controller to the popover.
 *
 * The DOM is deliberately dumb: every element renders from a `HushState`
 * snapshot, and every control calls a controller method. There is no state in
 * the view, so the popover being closed or the webview reloading cannot leave
 * the app disagreeing with itself.
 */

const controller = new HushController()

function el<T extends HTMLElement>(id: string): T | null {
  return document.getElementById(id) as T | null
}

function setText(id: string, text: string): void {
  const node = el(id)
  if (node) node.textContent = text
}

function setChecked(id: string, checked: boolean): void {
  const node = el<HTMLInputElement>(id)
  if (node) node.checked = checked
}

function render(state: HushState): void {
  const root = el('app')
  if (root) {
    root.dataset.sharing = String(state.share.sharing)
    root.dataset.engaged = String(state.engaged)
  }

  setText('status', state.status)
  setText('focus-state', state.engaged ? 'Focus is on' : 'Hush is idle')
  setChecked('toggle-focus', state.engaged)

  const sources = el('sources')
  if (sources) {
    sources.textContent = state.share.sources
      .map(s => (s.window ? `${s.app} — ${s.window}` : s.app))
      .join('\n')
    sources.hidden = state.share.sources.length === 0
  }

  // `unknown` — the sandbox cannot enumerate shortcuts — shows no prompt.
  // Nagging someone who has already finished setup is worse than silence.
  const setup = el('setup')
  if (setup) setup.hidden = state.shortcutsReady !== false

  const focusPermission = el('focus-permission')
  if (focusPermission) focusPermission.hidden = state.focusStatusReadable

  const recording = el('recording')
  if (recording) recording.hidden = state.screenRecording === 'granted'
  const accessibility = el('accessibility')
  if (accessibility) accessibility.hidden = state.accessibility === 'granted'

  setChecked('pref-automatic', state.prefs.automaticallyEnable)
  setChecked('pref-keep', state.prefs.keepEnabledAfterSharing)
  setChecked('pref-notify', state.prefs.showNotifications)
  setChecked('pref-login', state.prefs.launchAtLogin)

  setText('stat-sessions', String(state.stats.sessions))
  setText('stat-total', formatDuration(state.stats.totalActiveSeconds))
  setText('stat-average', formatDuration(averageSessionSeconds(state.stats)))
}

function reportError(error: unknown): void {
  setText('status', error instanceof Error ? error.message : String(error))
}

function bindCheckbox(id: string, apply: (checked: boolean) => Promise<void>): void {
  const node = el<HTMLInputElement>(id)
  if (!node) return
  node.addEventListener('change', () => {
    // The controller re-renders from its own state, so a rejected or clamped
    // change corrects the checkbox rather than leaving the UI lying.
    void apply(node.checked).catch(reportError)
  })
}

async function boot(): Promise<void> {
  controller.subscribe(render)

  bindCheckbox('toggle-focus', checked => controller.toggleFocus(checked))
  bindCheckbox('pref-automatic', checked => controller.updatePreferences({ automaticallyEnable: checked }))
  bindCheckbox('pref-keep', checked => controller.updatePreferences({ keepEnabledAfterSharing: checked }))
  bindCheckbox('pref-notify', checked => controller.updatePreferences({ showNotifications: checked }))
  bindCheckbox('pref-login', checked => controller.updatePreferences({ launchAtLogin: checked }))

  el('recheck-shortcuts')?.addEventListener('click', () => {
    void controller.refreshShortcuts().then(() => render(controller.snapshot()))
  })

  el('grant-focus')?.addEventListener('click', () => {
    void controller.requestFocusAuthorization().catch(reportError)
  })

  el('grant-recording')?.addEventListener('click', () => {
    void controller.requestScreenRecording()
  })
  el('grant-accessibility')?.addEventListener('click', () => {
    void controller.requestAccessibility().catch(reportError)
  })

  el('quit')?.addEventListener('click', () => {
    void controller.stop().then(() => app.quit()).catch(reportError)
  })

  await controller.start()
  const root = el('app')
  if (root) root.dataset.ready = 'true'
}

void boot().catch(reportError)

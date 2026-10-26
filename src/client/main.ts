import type { HushState } from '../runtime/controller'
import { app, nativeTray, nativeWindow } from '@stacksjs/desktop/browser'
import { HUSH_TRAY_ICON } from '../brand'
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
    root.dataset.sharing = state.sharingReadable ? String(state.share.sharing) : 'unknown'
    root.dataset.engaged = String(state.engaged)
    root.dataset.transitionPending = String(state.transitionPending)
  }

  setText('status', state.status)
  setText('focus-state', state.engaged ? 'Focus is on' : state.systemFocus === true ? 'Your existing Focus is on' : 'Hush is idle')
  const ready = state.shortcutsReady !== false && state.focusStatusReadable && state.screenRecording === 'granted' && state.accessibility === 'granted'
  setText('readiness', !ready ? 'Setup needed' : state.sharingReadable ? 'All set' : 'Checking…')
  setText('hero-title', !state.sharingReadable ? 'Getting ready…' : state.engaged ? 'Enjoy a little quiet.' : state.share.sharing ? 'Your Focus comes first.' : 'Ready when you share.')
  setText('hero-description', !state.sharingReadable ? 'Checking your Mac’s sharing controls.' : state.engaged ? 'Notifications can wait. Be here, now.' : state.systemFocus === true ? 'Your existing Focus stays just as you left it.' : 'Your next call, without the interruptions.')
  setChecked('toggle-focus', state.engaged || state.systemFocus === true)
  const focusControl = el<HTMLInputElement>('toggle-focus')
  if (focusControl) {
    focusControl.disabled = state.systemFocus === true && !state.engaged
    focusControl.title = focusControl.disabled ? 'Change your existing Focus in Control Center.' : 'Turn Do Not Disturb on or off for this session.'
  }

  const sources = el('sources')
  if (sources) {
    sources.textContent = state.share.sources
      .map(s => (s.window ? `${s.app} — ${s.window}` : s.app))
      .join('\n')
    sources.hidden = !state.sharingReadable || state.share.sources.length === 0
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
  const errorText = error instanceof Error ? error.message : typeof error === 'string' ? error : error && typeof error === 'object' && 'message' in error && typeof error.message === 'string' ? error.message : 'An unexpected error occurred. Please try again.'
  setText('error', errorText)
  const message = el('error')
  if (message) message.hidden = false
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
    void controller.requestScreenRecording().catch(reportError)
  })
  el('grant-accessibility')?.addEventListener('click', () => {
    void controller.requestAccessibility().catch(reportError)
  })

  el('quit')?.addEventListener('click', () => {
    contentObserver?.disconnect()
    void controller.stop().then(() => app.quit()).catch(reportError)
  })

  window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') void nativeWindow.hide()
  })
  window.addEventListener('craft:window:focus', () => {
    el('app')?.focus({ preventScroll: true })
    void controller.refreshNativeState().catch(reportError)
  })
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) void controller.refreshNativeState().catch(reportError)
  })

  await controller.start()
  await nativeTray.setIcon(HUSH_TRAY_ICON)
  await nativeTray.setTitle('')
  await nativeTray.setTooltip('Hush — a little peace of mind')
  const root = el('app')
  if (root) {
    root.dataset.ready = 'true'
    if (typeof ResizeObserver !== 'undefined' && nativeWindow.available) {
      contentObserver = new ResizeObserver(() => {
        const height = Math.min(Math.ceil(root.scrollHeight), window.screen.availHeight - 48)
        if (height > 0) void nativeWindow.setSize(368, height)
      })
      contentObserver.observe(root)
    }
  }
}

let contentObserver: ResizeObserver | undefined
void boot().catch(reportError)

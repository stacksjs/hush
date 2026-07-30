import type { FocusAction, PolicyState, Preferences } from './types'

/**
 * The decision engine: given what the detector sees and what the user wants,
 * decide whether Focus should change.
 *
 * Two rules carry all the weight.
 *
 * **Debounce both directions.** A conferencing app's sharing control is a real
 * window that comes and goes — it is rebuilt when you switch which window you
 * share, and it flickers while a share is being set up. Reacting to the raw
 * signal means Focus turning on and off repeatedly during a single meeting,
 * which is worse than not reacting at all. A transition only takes effect once
 * the new signal has held for its delay.
 *
 * **Never touch Focus that Hush did not turn on.** If the user set a Focus
 * themselves, a share ending must not clear it. `engaged` tracks ownership,
 * and `disable` is only ever emitted for a Focus this policy engaged.
 */
export function evaluate(
  sharing: boolean,
  prefs: Preferences,
  state: PolicyState,
  now: number,
): { action: FocusAction, state: PolicyState } {
  const desired = sharing && prefs.automaticallyEnable

  // Sharing ended, but the user asked to stay in Focus afterwards. Hold the
  // engagement so a *later* share doesn't double-count as a new session, and
  // so the menu still offers "turn Focus off".
  if (!desired && state.engaged && prefs.keepEnabledAfterSharing) {
    return { action: 'none', state: { engaged: true, pending: null } }
  }

  // Already where we want to be — drop any pending transition, since the
  // signal has come back to the current state on its own.
  if (desired === state.engaged) {
    return { action: 'none', state: { engaged: state.engaged, pending: null } }
  }

  const delay = desired ? prefs.activationDelayMs : prefs.deactivationDelayMs

  // First evaluation that disagrees with the current state: start the clock.
  if (!state.pending || state.pending.target !== desired) {
    // A zero delay means "act immediately" — don't make the caller wait for a
    // second evaluation to see any effect.
    if (delay <= 0) {
      return { action: desired ? 'enable' : 'disable', state: { engaged: desired, pending: null } }
    }
    return { action: 'none', state: { engaged: state.engaged, pending: { target: desired, since: now } } }
  }

  // The signal has held. `>=` so a delay of exactly one interval settles on the
  // interval boundary rather than one tick later.
  if (now - state.pending.since >= delay) {
    return { action: desired ? 'enable' : 'disable', state: { engaged: desired, pending: null } }
  }

  return { action: 'none', state }
}

/**
 * Apply a manual toggle from the menu.
 *
 * Manual actions are immediate — no debounce — and they take ownership of the
 * Focus either way, so a manually enabled Focus is still cleaned up when the
 * share ends. Any pending automatic transition is dropped: the user has just
 * stated their intent, and letting a timer overrule it a second later is the
 * kind of behaviour that makes an app feel possessed.
 */
export function toggleManually(
  state: PolicyState,
  enabled: boolean,
): { action: FocusAction, state: PolicyState } {
  if (enabled === state.engaged && state.pending === null) {
    return { action: 'none', state }
  }
  return {
    action: enabled ? 'enable' : 'disable',
    state: { engaged: enabled, pending: null },
  }
}

/**
 * Human-readable reason for the current state, for the menu and the popover.
 *
 * Naming the app that triggered Hush is the difference between "why is my Mac
 * silent?" and "right, I'm sharing in Zoom".
 */
export function describe(sharing: boolean, sources: Array<{ app: string }>, engaged: boolean): string {
  if (sharing) {
    const apps = [...new Set(sources.map(s => s.app).filter(Boolean))]
    if (apps.length === 0) return 'Screen is being shared'
    if (apps.length === 1) return `Sharing in ${apps[0]}`
    return `Sharing in ${apps.slice(0, -1).join(', ')} and ${apps[apps.length - 1]}`
  }
  return engaged ? 'Focus on — sharing ended' : 'Not sharing'
}

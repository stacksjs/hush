import type { PolicyState, Preferences } from '../src/core/types'
import { describe, expect, it } from 'bun:test'
import { describe as describeState, evaluate, toggleManually } from '../src/core/policy'
import { DEFAULT_PREFERENCES } from '../src/core/preferences'
import { initialPolicyState } from '../src/core/types'

function prefs(overrides: Partial<Preferences> = {}): Preferences {
  return { ...DEFAULT_PREFERENCES, ...overrides }
}

/** Drive the policy over a series of (sharing, time) samples. */
function run(
  samples: Array<[boolean, number]>,
  p: Preferences,
  start: PolicyState = initialPolicyState(),
): { actions: string[], state: PolicyState } {
  let state = start
  const actions: string[] = []
  for (const [sharing, now] of samples) {
    const r = evaluate(sharing, p, state, now)
    state = r.state
    if (r.action !== 'none') actions.push(`${r.action}@${now}`)
  }
  return { actions, state }
}

describe('evaluate', () => {
  it('does nothing while nothing is happening', () => {
    const { actions, state } = run([[false, 0], [false, 1000], [false, 2000]], prefs())
    expect(actions).toEqual([])
    expect(state.engaged).toBe(false)
  })

  it('waits out the activation delay before enabling', () => {
    const p = prefs({ activationDelayMs: 1000 })
    const { actions } = run([[true, 0], [true, 500], [true, 1000]], p)
    expect(actions).toEqual(['enable@1000'])
  })

  it('ignores a share that disappears before the delay elapses', () => {
    const p = prefs({ activationDelayMs: 1000 })
    const { actions, state } = run([[true, 0], [true, 500], [false, 800], [false, 2000]], p)
    expect(actions).toEqual([])
    expect(state.engaged).toBe(false)
    expect(state.pending).toBeNull()
  })

  it('rides out a sharing toolbar that flickers mid-session', () => {
    // The case that makes a naive implementation unusable: switching which
    // window you share tears down and rebuilds the sharing control.
    const p = prefs({ activationDelayMs: 1000, deactivationDelayMs: 5000 })
    const { actions, state } = run([
      [true, 0],
      [true, 1000], // enable
      [false, 3000], // toolbar rebuilt — starts the deactivation clock
      [true, 4000], // back before the clock ran out
      [true, 9000],
    ], p)
    expect(actions).toEqual(['enable@1000'])
    expect(state.engaged).toBe(true)
  })

  it('disables once sharing has been clear for the deactivation delay', () => {
    const p = prefs({ activationDelayMs: 0, deactivationDelayMs: 5000 })
    const { actions } = run([[true, 0], [false, 1000], [false, 5000], [false, 6000]], p)
    expect(actions).toEqual(['enable@0', 'disable@6000'])
  })

  it('acts immediately when a delay is zero', () => {
    const p = prefs({ activationDelayMs: 0, deactivationDelayMs: 0 })
    const { actions } = run([[true, 0], [false, 10]], p)
    expect(actions).toEqual(['enable@0', 'disable@10'])
  })

  it('settles exactly on the delay boundary, not a tick later', () => {
    const p = prefs({ activationDelayMs: 2000 })
    const { actions } = run([[true, 0], [true, 2000]], p)
    expect(actions).toEqual(['enable@2000'])
  })

  it('never engages when automatic activation is off', () => {
    const p = prefs({ automaticallyEnable: false, activationDelayMs: 0 })
    const { actions, state } = run([[true, 0], [true, 10_000]], p)
    expect(actions).toEqual([])
    expect(state.engaged).toBe(false)
  })

  it('keeps Focus on after sharing ends when asked to', () => {
    const p = prefs({ activationDelayMs: 0, deactivationDelayMs: 0, keepEnabledAfterSharing: true })
    const { actions, state } = run([[true, 0], [false, 1000], [false, 60_000]], p)
    expect(actions).toEqual(['enable@0'])
    expect(state.engaged).toBe(true)
  })

  it('does not re-enable for a second share while already engaged', () => {
    const p = prefs({ activationDelayMs: 0, deactivationDelayMs: 0, keepEnabledAfterSharing: true })
    const { actions } = run([[true, 0], [false, 100], [true, 200], [true, 300]], p)
    expect(actions).toEqual(['enable@0'])
  })

  it('never disables a Focus it did not engage', () => {
    // Fresh state: Hush has engaged nothing. Sharing ending must produce no
    // action at all, or it would clear a Focus the user set themselves.
    const p = prefs({ deactivationDelayMs: 0 })
    const { actions } = run([[false, 0], [false, 1000]], p)
    expect(actions).toEqual([])
  })
})

describe('toggleManually', () => {
  it('acts immediately and takes ownership', () => {
    const r = toggleManually(initialPolicyState(), true)
    expect(r.action).toBe('enable')
    expect(r.state.engaged).toBe(true)
  })

  it('is a no-op when already in the requested state', () => {
    const r = toggleManually({ engaged: true, pending: null }, true)
    expect(r.action).toBe('none')
  })

  it('cancels a pending automatic transition rather than letting it override', () => {
    const state: PolicyState = { engaged: false, pending: { target: true, since: 0 } }
    const r = toggleManually(state, false)
    expect(r.state.pending).toBeNull()
    // Still emits the action so the caller re-asserts the off state.
    expect(r.action).toBe('disable')
  })

  it('a manually enabled Focus is still cleaned up when sharing ends', () => {
    const manual = toggleManually(initialPolicyState(), true)
    const p = prefs({ deactivationDelayMs: 0 })
    const { actions } = run([[false, 1000]], p, manual.state)
    expect(actions).toEqual(['disable@1000'])
  })
})

describe('describe', () => {
  it('names the sharing app', () => {
    expect(describeState(true, [{ app: 'zoom.us' }], true)).toBe('Sharing in zoom.us')
  })

  it('lists several apps readably and de-duplicates', () => {
    const sources = [{ app: 'zoom.us' }, { app: 'zoom.us' }, { app: 'Google Chrome' }]
    expect(describeState(true, sources, true)).toBe('Sharing in zoom.us and Google Chrome')
  })

  it('falls back when the source has no app name', () => {
    expect(describeState(true, [{ app: '' }], true)).toBe('Screen is being shared')
  })

  it('distinguishes a lingering Focus from an idle one', () => {
    expect(describeState(false, [], true)).toBe('Focus on — sharing ended')
    expect(describeState(false, [], false)).toBe('Not sharing')
  })
})

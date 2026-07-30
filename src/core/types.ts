/**
 * Shared types for Hush's core.
 *
 * Everything here is platform-free on purpose: the decision engine, the
 * preferences shape and the statistics shape are all plain data, so they can be
 * exercised without a window, a bridge or a Mac.
 */

/** Why Hush believes the screen is being shared. Mirrors Craft's signal set. */
export type ShareKind = 'system' | 'remote' | 'conference' | 'recording'

export interface ShareSource {
  app: string
  window: string
  kind: ShareKind
}

/** What the detector currently observes. */
export interface ShareState {
  sharing: boolean
  sources: ShareSource[]
}

export interface Preferences {
  /** Turn Focus on automatically when a share starts. */
  automaticallyEnable: boolean
  /**
   * Leave Focus on after the share ends. For people who use a share as a
   * "heads down" signal rather than a meeting marker.
   */
  keepEnabledAfterSharing: boolean
  /** Post a system notification whenever Hush changes Focus. */
  showNotifications: boolean
  /** Start Hush at login. */
  launchAtLogin: boolean
  /** How often the screen-sharing signals are re-evaluated. */
  detectionIntervalMs: number
  /**
   * How long sharing must hold before Focus turns on. Guards against a
   * sharing control that flickers during setup.
   */
  activationDelayMs: number
  /**
   * How long sharing must stay clear before Focus turns off. This one matters
   * more: conferencing apps routinely tear down and rebuild their sharing
   * toolbar mid-session — when switching which window is shared, for instance
   * — and without a delay every one of those blips would unsilence the machine
   * for a moment.
   */
  deactivationDelayMs: number
  /** Shortcut that turns Focus on. */
  focusOnShortcut: string
  /** Shortcut that turns Focus off. */
  focusOffShortcut: string
}

export interface Statistics {
  /** Shares Hush has reacted to. */
  sessions: number
  /** Times the user toggled Focus from the menu themselves. */
  manualToggles: number
  /** Total seconds Focus has been on because of Hush. */
  totalActiveSeconds: number
  /** Epoch ms of the last automatic activation, or null. */
  lastActivatedAt: number | null
  /** Epoch ms of the last automatic deactivation, or null. */
  lastDeactivatedAt: number | null
  /** Epoch ms of first run. */
  installedAt: number
}

/** What the policy wants done, if anything. */
export type FocusAction = 'enable' | 'disable' | 'none'

/**
 * Everything the policy needs to remember between evaluations.
 *
 * Kept out of the policy function itself so it stays pure — the caller owns
 * the state and can snapshot, restore or assert on it.
 */
export interface PolicyState {
  /** Whether Focus is currently on *because of Hush*. */
  engaged: boolean
  /** The pending transition, if the signal has changed but not yet settled. */
  pending: { target: boolean, since: number } | null
}

export function initialPolicyState(): PolicyState {
  return { engaged: false, pending: null }
}

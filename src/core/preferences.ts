import type { Preferences } from './types'

/**
 * Shortcut names Hush expects the user to create once in the Shortcuts app.
 *
 * macOS does not let a third-party app set Focus directly — the system service
 * requires an Apple-private entitlement — so a Shortcut containing the *Set
 * Focus* action performs the change on the user's behalf. These are the names
 * the setup flow tells them to use.
 */
export const FOCUS_ON_SHORTCUT = 'Hush Focus On'
export const FOCUS_OFF_SHORTCUT = 'Hush Focus Off'

export const DEFAULT_PREFERENCES: Preferences = {
  automaticallyEnable: true,
  keepEnabledAfterSharing: false,
  showNotifications: true,
  launchAtLogin: false,
  detectionIntervalMs: 2000,
  activationDelayMs: 1000,
  // Deliberately longer than activation. Ending a share is rarely urgent, and
  // conferencing apps rebuild their sharing toolbar mid-session — a short
  // deactivation delay turns each of those into a burst of notifications.
  deactivationDelayMs: 5000,
  focusOnShortcut: FOCUS_ON_SHORTCUT,
  focusOffShortcut: FOCUS_OFF_SHORTCUT,
}

/** Bounds that keep a hand-edited preferences file from producing a broken app. */
const LIMITS = {
  detectionIntervalMs: [250, 60_000],
  activationDelayMs: [0, 60_000],
  deactivationDelayMs: [0, 300_000],
} as const

function clampNumber(value: unknown, fallback: number, [min, max]: readonly [number, number]): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback
  return Math.min(max, Math.max(min, Math.round(value)))
}

function asBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}

function asShortcut(value: unknown, fallback: string): string {
  if (typeof value !== 'string') return fallback
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : fallback
}

/**
 * Coerce arbitrary parsed JSON into a valid `Preferences`.
 *
 * The file lives in Application Support where anything can edit it, and a
 * partial or stale file is the normal case after an upgrade — so every field
 * falls back independently rather than the whole file being rejected.
 */
export function normalizePreferences(input: unknown): Preferences {
  const raw = (typeof input === 'object' && input !== null ? input : {}) as Record<string, unknown>
  const d = DEFAULT_PREFERENCES

  return {
    automaticallyEnable: asBoolean(raw.automaticallyEnable, d.automaticallyEnable),
    keepEnabledAfterSharing: asBoolean(raw.keepEnabledAfterSharing, d.keepEnabledAfterSharing),
    showNotifications: asBoolean(raw.showNotifications, d.showNotifications),
    launchAtLogin: asBoolean(raw.launchAtLogin, d.launchAtLogin),
    detectionIntervalMs: clampNumber(raw.detectionIntervalMs, d.detectionIntervalMs, LIMITS.detectionIntervalMs),
    activationDelayMs: clampNumber(raw.activationDelayMs, d.activationDelayMs, LIMITS.activationDelayMs),
    deactivationDelayMs: clampNumber(raw.deactivationDelayMs, d.deactivationDelayMs, LIMITS.deactivationDelayMs),
    focusOnShortcut: asShortcut(raw.focusOnShortcut, d.focusOnShortcut),
    focusOffShortcut: asShortcut(raw.focusOffShortcut, d.focusOffShortcut),
  }
}

/** Parse the on-disk document, tolerating an empty or corrupt file. */
export function parsePreferences(text: string): Preferences {
  if (!text.trim()) return { ...DEFAULT_PREFERENCES }
  try {
    return normalizePreferences(JSON.parse(text))
  }
  catch {
    // A corrupt file must not stop the app from starting. Defaults get written
    // back on the next change, which repairs it.
    return { ...DEFAULT_PREFERENCES }
  }
}

export function serializePreferences(prefs: Preferences): string {
  return `${JSON.stringify(prefs, null, 2)}\n`
}

import type { Statistics } from './types'

export function emptyStatistics(now: number): Statistics {
  return {
    sessions: 0,
    manualToggles: 0,
    totalActiveSeconds: 0,
    lastActivatedAt: null,
    lastDeactivatedAt: null,
    installedAt: now,
  }
}

function asCount(value: unknown, fallback: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) return fallback
  return Math.floor(value)
}

function asTimestamp(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : null
}

export function normalizeStatistics(input: unknown, now: number): Statistics {
  const raw = (typeof input === 'object' && input !== null ? input : {}) as Record<string, unknown>
  return {
    sessions: asCount(raw.sessions, 0),
    manualToggles: asCount(raw.manualToggles, 0),
    totalActiveSeconds: asCount(raw.totalActiveSeconds, 0),
    lastActivatedAt: asTimestamp(raw.lastActivatedAt),
    lastDeactivatedAt: asTimestamp(raw.lastDeactivatedAt),
    installedAt: asTimestamp(raw.installedAt) ?? now,
  }
}

export function parseStatistics(text: string, now: number): Statistics {
  if (!text.trim()) return emptyStatistics(now)
  try {
    return normalizeStatistics(JSON.parse(text), now)
  }
  catch {
    return emptyStatistics(now)
  }
}

export function serializeStatistics(stats: Statistics): string {
  return `${JSON.stringify(stats, null, 2)}\n`
}

/** Record Focus turning on. Returns a new object; the input is untouched. */
export function recordActivation(stats: Statistics, now: number, manual: boolean): Statistics {
  return {
    ...stats,
    sessions: stats.sessions + 1,
    manualToggles: stats.manualToggles + (manual ? 1 : 0),
    lastActivatedAt: now,
  }
}

/**
 * Record Focus turning off, adding the elapsed time to the running total.
 *
 * A clock that jumps backwards — a manual change, an NTP correction, waking
 * from sleep in another timezone — would otherwise subtract from the total, so
 * a negative span is dropped rather than counted.
 */
export function recordDeactivation(stats: Statistics, now: number, manual: boolean): Statistics {
  const startedAt = stats.lastActivatedAt
  const elapsed = startedAt !== null && now > startedAt ? Math.round((now - startedAt) / 1000) : 0

  return {
    ...stats,
    manualToggles: stats.manualToggles + (manual ? 1 : 0),
    totalActiveSeconds: stats.totalActiveSeconds + elapsed,
    lastDeactivatedAt: now,
  }
}

/** Mean session length in seconds, or 0 before the first session completes. */
export function averageSessionSeconds(stats: Statistics): number {
  return stats.sessions > 0 ? Math.round(stats.totalActiveSeconds / stats.sessions) : 0
}

/** `"2h 15m"`, `"15m"`, `"45s"` — compact enough for a menubar popover. */
export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return '0s'
  const total = Math.round(seconds)
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  if (hours > 0) return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`
  if (minutes > 0) return `${minutes}m`
  return `${total}s`
}

import { describe, expect, it } from 'bun:test'
import {
  averageSessionSeconds,
  emptyStatistics,
  formatDuration,
  normalizeStatistics,
  parseStatistics,
  recordActivation,
  recordDeactivation,
  serializeStatistics,
} from '../src/core/statistics'

const T0 = 1_700_000_000_000

describe('recording', () => {
  it('counts a session and remembers when it started', () => {
    const s = recordActivation(emptyStatistics(T0), T0, false)
    expect(s.sessions).toBe(1)
    expect(s.lastActivatedAt).toBe(T0)
    expect(s.manualToggles).toBe(0)
  })

  it('counts manual toggles separately from sessions', () => {
    let s = recordActivation(emptyStatistics(T0), T0, true)
    s = recordDeactivation(s, T0 + 1000, true)
    expect(s.sessions).toBe(1)
    expect(s.manualToggles).toBe(2)
  })

  it('accumulates active time across sessions', () => {
    let s = emptyStatistics(T0)
    s = recordActivation(s, T0, false)
    s = recordDeactivation(s, T0 + 60_000, false)
    s = recordActivation(s, T0 + 120_000, false)
    s = recordDeactivation(s, T0 + 150_000, false)
    expect(s.totalActiveSeconds).toBe(90)
    expect(s.sessions).toBe(2)
  })

  it('does not subtract time when the clock moves backwards', () => {
    // Sleep/wake and NTP corrections both do this. Counting the negative span
    // would silently corrupt the running total.
    let s = recordActivation(emptyStatistics(T0), T0, false)
    s = recordDeactivation(s, T0 - 5000, false)
    expect(s.totalActiveSeconds).toBe(0)
  })

  it('handles a deactivation with no recorded activation', () => {
    const s = recordDeactivation(emptyStatistics(T0), T0 + 1000, false)
    expect(s.totalActiveSeconds).toBe(0)
    expect(s.lastDeactivatedAt).toBe(T0 + 1000)
  })

  it('treats statistics as immutable', () => {
    const before = emptyStatistics(T0)
    recordActivation(before, T0, false)
    expect(before.sessions).toBe(0)
  })
})

describe('normalizeStatistics', () => {
  it('repairs missing and malformed fields', () => {
    const s = normalizeStatistics({ sessions: -4, totalActiveSeconds: 'lots', installedAt: 0 }, T0)
    expect(s.sessions).toBe(0)
    expect(s.totalActiveSeconds).toBe(0)
    expect(s.installedAt).toBe(T0)
  })

  it('preserves a real install date', () => {
    expect(normalizeStatistics({ installedAt: 1234 }, T0).installedAt).toBe(1234)
  })

  it('floors fractional counters', () => {
    expect(normalizeStatistics({ sessions: 3.9 }, T0).sessions).toBe(3)
  })

  it('round-trips through parse/serialize', () => {
    const s = recordActivation(emptyStatistics(T0), T0, false)
    expect(parseStatistics(serializeStatistics(s), T0)).toEqual(s)
  })

  it('survives a corrupt file', () => {
    expect(parseStatistics('not json at all', T0)).toEqual(emptyStatistics(T0))
  })
})

describe('derived values', () => {
  it('averages only over completed sessions', () => {
    let s = emptyStatistics(T0)
    s = recordActivation(s, T0, false)
    s = recordDeactivation(s, T0 + 100_000, false)
    s = recordActivation(s, T0 + 200_000, false)
    s = recordDeactivation(s, T0 + 300_000, false)
    expect(averageSessionSeconds(s)).toBe(100)
  })

  it('does not divide by zero before the first session', () => {
    expect(averageSessionSeconds(emptyStatistics(T0))).toBe(0)
  })

  it('formats durations compactly', () => {
    expect(formatDuration(0)).toBe('0s')
    expect(formatDuration(45)).toBe('45s')
    expect(formatDuration(60)).toBe('1m')
    expect(formatDuration(3600)).toBe('1h')
    expect(formatDuration(8100)).toBe('2h 15m')
    expect(formatDuration(-10)).toBe('0s')
    expect(formatDuration(Number.NaN)).toBe('0s')
  })
})

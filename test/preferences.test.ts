import { describe, expect, it } from 'bun:test'
import {
  DEFAULT_PREFERENCES,
  normalizePreferences,
  parsePreferences,
  serializePreferences,
} from '../src/core/preferences'

describe('normalizePreferences', () => {
  it('returns defaults for an empty object', () => {
    expect(normalizePreferences({})).toEqual(DEFAULT_PREFERENCES)
  })

  it('returns defaults for anything that is not an object', () => {
    for (const input of [null, undefined, 42, 'nope', []]) {
      expect(normalizePreferences(input)).toEqual(DEFAULT_PREFERENCES)
    }
  })

  it('keeps valid values', () => {
    const p = normalizePreferences({ automaticallyEnable: false, deactivationDelayMs: 8000 })
    expect(p.automaticallyEnable).toBe(false)
    expect(p.deactivationDelayMs).toBe(8000)
  })

  it('falls back per field, so a partial file still starts the app', () => {
    const p = normalizePreferences({ showNotifications: 'yes', keepEnabledAfterSharing: true })
    expect(p.showNotifications).toBe(DEFAULT_PREFERENCES.showNotifications)
    expect(p.keepEnabledAfterSharing).toBe(true)
  })

  it('clamps intervals into a range the app can actually run at', () => {
    expect(normalizePreferences({ detectionIntervalMs: 1 }).detectionIntervalMs).toBe(250)
    expect(normalizePreferences({ detectionIntervalMs: 10_000_000 }).detectionIntervalMs).toBe(60_000)
    expect(normalizePreferences({ deactivationDelayMs: -5 }).deactivationDelayMs).toBe(0)
  })

  it('rejects non-finite numbers rather than propagating NaN into a timer', () => {
    expect(normalizePreferences({ detectionIntervalMs: Number.NaN }).detectionIntervalMs)
      .toBe(DEFAULT_PREFERENCES.detectionIntervalMs)
    // Infinity is not finite, so it falls back rather than clamping — a
    // clamped Infinity would look like a deliberate one-minute delay.
    expect(normalizePreferences({ activationDelayMs: Number.POSITIVE_INFINITY }).activationDelayMs)
      .toBe(DEFAULT_PREFERENCES.activationDelayMs)
  })

  it('rounds fractional intervals', () => {
    expect(normalizePreferences({ activationDelayMs: 1500.7 }).activationDelayMs).toBe(1501)
  })

  it('ignores blank shortcut names', () => {
    const p = normalizePreferences({ focusOnShortcut: '   ', focusOffShortcut: 'My Off' })
    expect(p.focusOnShortcut).toBe(DEFAULT_PREFERENCES.focusOnShortcut)
    expect(p.focusOffShortcut).toBe('My Off')
  })

  it('trims shortcut names, since a stray space breaks the lookup', () => {
    expect(normalizePreferences({ focusOnShortcut: '  Focus On  ' }).focusOnShortcut).toBe('Focus On')
  })
})

describe('parsePreferences', () => {
  it('handles an empty file', () => {
    expect(parsePreferences('')).toEqual(DEFAULT_PREFERENCES)
    expect(parsePreferences('   \n')).toEqual(DEFAULT_PREFERENCES)
  })

  it('handles a corrupt file instead of refusing to start', () => {
    expect(parsePreferences('{ this is not json')).toEqual(DEFAULT_PREFERENCES)
  })

  it('round-trips through serialize', () => {
    const custom = { ...DEFAULT_PREFERENCES, keepEnabledAfterSharing: true, activationDelayMs: 250 }
    expect(parsePreferences(serializePreferences(custom))).toEqual(custom)
  })

  it('serializes with a trailing newline so the file is well-formed', () => {
    expect(serializePreferences(DEFAULT_PREFERENCES).endsWith('\n')).toBe(true)
  })
})

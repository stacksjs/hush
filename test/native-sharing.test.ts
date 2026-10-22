import { describe, expect, it } from 'bun:test'
import { isNativeTabSharing } from '../scripts/native-sharing'

describe('native tab-source validation', () => {
  it('accepts the exact Dia native banner source', () => {
    expect(isNativeTabSharing({ app: 'Dia', window: 'Browser tab sharing' })).toBe(true)
    expect(isNativeTabSharing({ app: 'Dia', window: 'Hush capture check' })).toBe(false)
  })

  it('requires Chrome’s native sharing suffix and provider identity', () => {
    expect(isNativeTabSharing({ app: 'Google Chrome', window: 'Hush capture check - Tab content shared - Google Chrome' })).toBe(true)
    expect(isNativeTabSharing({ app: 'Google Chrome', window: 'Hush capture check - Google Chrome' })).toBe(false)
    expect(isNativeTabSharing({ app: 'TextEdit', window: 'Hush capture check - Tab content shared - Google Chrome' })).toBe(false)
    expect(isNativeTabSharing({ app: 'TextEdit', window: 'Browser tab sharing' })).toBe(false)
  })

  it('serializes the same predicate used inside real WebKit', () => {
    const nativePredicate = new Function(`return (${isNativeTabSharing.toString()})`)() as typeof isNativeTabSharing
    expect(nativePredicate({ app: 'Dia', window: 'Browser tab sharing' })).toBe(true)
    expect(nativePredicate({ app: 'Dia', window: 'Sharing this tab' })).toBe(false)
  })
})

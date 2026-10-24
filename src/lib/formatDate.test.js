import { describe, expect, it } from 'vitest'
import { clubNow, formatEventTime } from './formatDate.js'

// These run with `npm test`.
describe('formatEventTime', () => {
  it('shows the day, start and end time exactly as stored', () => {
    expect(formatEventTime('2026-11-04T19:00:00', '2026-11-04T21:00:00')).toBe(
      'Wed, Nov 4 · 7:00 PM – 9:00 PM',
    )
  })

  it('shows only the start when there is no end time', () => {
    expect(formatEventTime('2026-11-04T19:30:00', null)).toBe(
      'Wed, Nov 4 · 7:30 PM',
    )
  })

  it('also reads the database format with a space instead of a T', () => {
    expect(formatEventTime('2026-07-01 12:00:00', null)).toBe(
      'Wed, Jul 1 · 12:00 PM',
    )
  })
})

describe('clubNow', () => {
  it('gives New York wall-clock time in winter (UTC-5)', () => {
    expect(clubNow(new Date('2026-11-05T00:30:00Z'))).toBe(
      '2026-11-04T19:30:00',
    )
  })

  it('gives New York wall-clock time in summer (UTC-4)', () => {
    expect(clubNow(new Date('2026-07-01T23:00:00Z'))).toBe(
      '2026-07-01T19:00:00',
    )
  })

  it('writes midnight as 00, not 24', () => {
    expect(clubNow(new Date('2026-11-05T05:00:00Z'))).toBe(
      '2026-11-05T00:00:00',
    )
  })
})

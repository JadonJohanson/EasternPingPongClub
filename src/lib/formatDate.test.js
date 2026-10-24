import { describe, expect, it } from 'vitest'
import { formatEventTime } from './formatDate.js'

// These run with `npm test`. Times are written in UTC ("Z") and the function
// must show them in the club's time zone (America/New_York).
describe('formatEventTime', () => {
  it('shows the day, start and end time in club time', () => {
    // 2026-11-04 is after daylight saving ends (Nov 1), so New York is UTC-5.
    expect(
      formatEventTime('2026-11-05T00:00:00Z', '2026-11-05T02:00:00Z'),
    ).toBe('Wed, Nov 4 · 7:00 PM – 9:00 PM')
  })

  it('shows only the start when there is no end time', () => {
    expect(formatEventTime('2026-11-05T00:30:00Z', null)).toBe(
      'Wed, Nov 4 · 7:30 PM',
    )
  })

  it('uses daylight saving time in the summer (UTC-4)', () => {
    expect(formatEventTime('2026-07-01T23:00:00Z', null)).toBe(
      'Wed, Jul 1 · 7:00 PM',
    )
  })
})

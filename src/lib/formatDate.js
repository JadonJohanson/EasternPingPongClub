import { CLUB_TIME_ZONE } from '../siteConfig.js'

// Event times are stored as plain club wall-clock time, with no time zone, and
// arrive from the database as text like "2026-11-04T19:00:00". We show that
// exactly as written, so a visitor's phone time zone can never change it.
//   "Wed, Nov 4 · 7:00 PM – 9:00 PM"
export function formatEventTime(startsAt, endsAt) {
  const startText = formatTime(startsAt)
  const day = new Intl.DateTimeFormat('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    timeZone: 'UTC',
  }).format(wallClockToDate(startsAt))
  if (!endsAt) return `${day} · ${startText}`
  return `${day} · ${startText} – ${formatTime(endsAt)}`
}

// "Now" as club wall-clock text ("2026-11-04T19:30:00"), for comparing with
// the stored event times in a database query.
export function clubNow(date = new Date()) {
  // The Swedish locale writes dates as "2026-11-04 19:30:00", which is the
  // order we need. `hourCycle: 'h23'` keeps midnight as 00, not 24.
  return new Intl.DateTimeFormat('sv-SE', {
    timeZone: CLUB_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  })
    .format(date)
    .replace(' ', 'T')
}

function formatTime(text) {
  return new Intl.DateTimeFormat('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    timeZone: 'UTC',
  }).format(wallClockToDate(text))
}

// Reads "2026-11-04T19:00:00" as those exact numbers. We pretend they are UTC
// and format them as UTC, so no time zone conversion ever happens.
function wallClockToDate(text) {
  const [year, month, day, hour = 0, minute = 0] = text
    .split(/[-T:\s]/)
    .map(Number)
  return new Date(Date.UTC(year, month - 1, day, hour, minute))
}

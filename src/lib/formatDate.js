import { CLUB_TIME_ZONE } from '../siteConfig.js'

// Turns a start (and optional end) time from the database into friendly text,
// always shown in the club's time zone, whatever time zone the visitor is in.
//   "Wed, Nov 4 · 7:00 PM – 9:00 PM"
export function formatEventTime(startsAt, endsAt) {
  const start = new Date(startsAt)
  const day = new Intl.DateTimeFormat('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    timeZone: CLUB_TIME_ZONE,
  }).format(start)
  const time = new Intl.DateTimeFormat('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    timeZone: CLUB_TIME_ZONE,
  })
  const startText = time.format(start)
  if (!endsAt) return `${day} · ${startText}`
  return `${day} · ${startText} – ${time.format(new Date(endsAt))}`
}

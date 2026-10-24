import AsyncState from './AsyncState.jsx'
import { fetchNextEvent } from '../data/events.js'
import { isSupabaseConfigured } from '../lib/supabase.js'
import { useAsync } from '../lib/useAsync.js'
import { formatEventTime } from '../lib/formatDate.js'

// The "Next event" card on the Home page. It reads the soonest upcoming event
// from the database and shows it, or a friendly message if there is none.
export default function NextEvent() {
  // `fetchNextEvent` is defined outside this component, so it is the same
  // function on every draw and the request runs once, not in a loop.
  const { status, data, retry } = useAsync(fetchNextEvent)

  return (
    <section className="card home__next-event" aria-label="Next event">
      <p className="home__label">Next event</p>

      {!isSupabaseConfigured ? (
        // Happens when the site runs without a `.env` file.
        <p className="muted">
          The database is not connected yet. Add your Supabase settings to a
          .env file (see .env.example).
        </p>
      ) : (
        <AsyncState
          status={status}
          isEmpty={!data}
          onRetry={retry}
          emptyMessage="No events scheduled yet. Check back soon!"
          errorMessage="We could not load the next event."
        >
          {data && (
            <>
              <p className="home__event-name">{data.title}</p>
              <p className="home__event-time">
                {formatEventTime(data.starts_at, data.ends_at)}
              </p>
              {data.location && <p className="muted">{data.location}</p>}
            </>
          )}
        </AsyncState>
      )}
    </section>
  )
}

import { useCallback } from 'react'
import { Link, useParams } from 'react-router-dom'
import AsyncState from '../components/AsyncState.jsx'
import { fetchPlayer } from '../data/players.js'
import { isSupabaseConfigured } from '../lib/supabase.js'
import { useAsync } from '../lib/useAsync.js'

// One player's page, at /players/<id>. For now it shows only the name; the
// Tournament and Casual sections (record, rating, history) come later.
export default function PlayerProfile() {
  // `useParams` reads the `:playerId` part of the address.
  const { playerId } = useParams()

  // useCallback keeps the same function between draws unless the id changes,
  // so the request is not repeated in a loop (see useAsync).
  const load = useCallback(() => fetchPlayer(playerId), [playerId])
  const { status, data, retry } = useAsync(load)

  return (
    <section>
      <p>
        <Link to="/players">← All players</Link>
      </p>

      {!isSupabaseConfigured ? (
        <p className="muted">The database is not connected yet.</p>
      ) : (
        <AsyncState
          status={status}
          isEmpty={!data}
          onRetry={retry}
          emptyMessage="We couldn’t find that player."
        >
          <h1>{data?.display_name}</h1>
          <p className="muted">Tournament and casual stats are coming soon.</p>
        </AsyncState>
      )}
    </section>
  )
}

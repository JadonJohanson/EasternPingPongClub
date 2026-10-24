import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import AsyncState from '../components/AsyncState.jsx'
import { fetchPlayers } from '../data/players.js'
import { filterPlayers } from '../lib/search.js'
import { isSupabaseConfigured } from '../lib/supabase.js'
import { useAsync } from '../lib/useAsync.js'
import './Players.css'

// The member list: a search box and a link to each player's profile.
export default function Players() {
  const { status, data, retry } = useAsync(fetchPlayers)
  // What the visitor has typed in the search box.
  const [query, setQuery] = useState('')

  // Only re-filter when the list or the search text changes.
  const visible = useMemo(() => filterPlayers(data ?? [], query), [data, query])

  return (
    <section className="players">
      <h1>Players</h1>

      {!isSupabaseConfigured ? (
        <p className="muted">The database is not connected yet.</p>
      ) : (
        <AsyncState
          status={status}
          isEmpty={data?.length === 0}
          onRetry={retry}
          emptyMessage="No players yet."
        >
          <label className="players__search">
            <span className="visually-hidden">Search players</span>
            <input
              type="search"
              placeholder="Search players"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              autoComplete="off"
            />
          </label>

          <p className="muted players__count" role="status">
            {visible.length} of {data?.length} players
          </p>

          {visible.length === 0 ? (
            <p className="muted">No players match “{query.trim()}”.</p>
          ) : (
            <ul className="players__list">
              {visible.map((player) => (
                <li key={player.id}>
                  <Link to={`/players/${player.id}`}>
                    {player.display_name}
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </AsyncState>
      )}
    </section>
  )
}

import { useState } from 'react'
import { Link } from 'react-router-dom'
import AsyncState from '../components/AsyncState.jsx'
import Honeypot from '../components/Honeypot.jsx'
import PlayerPicker from '../components/PlayerPicker.jsx'
import { submitCasualMatch } from '../data/matches.js'
import { fetchPlayers } from '../data/players.js'
import {
  buildMatch,
  MAX_GAMES,
  POINTS_OPTIONS,
  tally,
  validateMatch,
} from '../lib/matchValidation.js'
import { isSupabaseConfigured } from '../lib/supabase.js'
import { useAsync } from '../lib/useAsync.js'
import '../components/FormField.css'
import './Play.css'

const NO_ONE = { playerId: '', guestName: '' }

// A fresh form: nobody chosen, the usual rules (to 11, win by 2), one game row.
function emptyForm() {
  return {
    a: NO_ONE,
    b: NO_ONE,
    pointsTo: 11,
    winByTwo: true,
    games: [{ a: '', b: '' }],
  }
}

// Log a casual game: pick two players, type the game scores, save.
// Casual games never change rankings; they only feed records and head-to-head.
export default function Play() {
  const { status: playersStatus, data: players, retry } = useAsync(fetchPlayers)

  const [values, setValues] = useState(emptyForm)
  const [errors, setErrors] = useState({})
  // 'idle', 'sending', 'done' or 'failed'.
  const [status, setStatus] = useState('idle')
  // The hidden bot-trap field (see the Honeypot component).
  const [website, setWebsite] = useState('')
  // Names shown on the thank-you screen.
  const [summary, setSummary] = useState('')

  const nameOf = (side) =>
    players?.find((p) => p.id === side.playerId)?.display_name ??
    side.guestName.trim()

  // Editing a field removes that field's old error message.
  const clearError = (key) =>
    setErrors((current) => ({ ...current, [key]: undefined }))

  const setSide = (key) => (side) => {
    clearError(key)
    setValues((current) => ({ ...current, [key]: side }))
  }

  const setGame = (index, key) => (event) => {
    const text = event.target.value
    clearError('games')
    setValues((current) => ({
      ...current,
      games: current.games.map((game, i) =>
        i === index ? { ...game, [key]: text } : game,
      ),
    }))
  }

  const addGame = () =>
    setValues((current) => ({
      ...current,
      games: [...current.games, { a: '', b: '' }],
    }))

  const removeGame = (index) =>
    setValues((current) => ({
      ...current,
      games: current.games.filter((_, i) => i !== index),
    }))

  async function handleSubmit(event) {
    event.preventDefault()
    if (status === 'sending') return

    const problems = validateMatch(values)
    setErrors(problems)
    if (Object.keys(problems).length > 0) return

    setStatus('sending')

    // A bot filled the hidden field: pretend it worked, send nothing.
    if (website) {
      setSummary('')
      setStatus('done')
      return
    }

    try {
      await submitCasualMatch(buildMatch(values))
      const { winsA, winsB } = tally(
        values.games,
        values.pointsTo,
        values.winByTwo,
      )
      const winner = winsA > winsB ? nameOf(values.a) : nameOf(values.b)
      const loser = winsA > winsB ? nameOf(values.b) : nameOf(values.a)
      setSummary(
        `${winner} beat ${loser} ${Math.max(winsA, winsB)}–${Math.min(winsA, winsB)}`,
      )
      setStatus('done')
    } catch (error) {
      console.error('Saving casual match failed', error)
      setStatus('failed')
    }
  }

  // Thank-you screen. "Play again" keeps nothing, so the next match starts fresh.
  if (status === 'done') {
    return (
      <div className="page play">
        <h1>Game saved</h1>
        {summary && <p className="play__summary">{summary}</p>}
        <p className="muted">
          Casual games count toward records and head-to-head, not rankings.
        </p>
        <button
          type="button"
          className="button play__submit"
          onClick={() => {
            setValues(emptyForm())
            setErrors({})
            setStatus('idle')
          }}
        >
          Log another game
        </button>
        <p>
          <Link to="/players">See players</Link>
        </p>
      </div>
    )
  }

  const { winsA, winsB } = tally(values.games, values.pointsTo, values.winByTwo)

  return (
    <div className="page play">
      <h1>Play</h1>
      <p className="muted">
        Log a casual game. It does not affect tournament rankings.
      </p>

      {!isSupabaseConfigured ? (
        <p className="card" role="status">
          The database is not connected yet, so games cannot be saved.
        </p>
      ) : (
        <AsyncState
          status={playersStatus}
          onRetry={retry}
          errorMessage="We could not load the player list. Please try again."
        >
          <form onSubmit={handleSubmit} noValidate>
            <PlayerPicker
              id="player-a"
              label="Player 1"
              players={players ?? []}
              value={values.a}
              onChange={setSide('a')}
              exclude={values.b.playerId}
              error={errors.a}
            />
            <PlayerPicker
              id="player-b"
              label="Player 2"
              players={players ?? []}
              value={values.b}
              onChange={setSide('b')}
              exclude={values.a.playerId}
              error={errors.b}
            />

            <fieldset className="play__rules">
              <legend className="field__label">Game rules</legend>
              <div className="play__rules-row">
                {POINTS_OPTIONS.map((points) => (
                  <label key={points} className="play__choice">
                    <input
                      type="radio"
                      name="points-to"
                      checked={values.pointsTo === points}
                      onChange={() =>
                        setValues((c) => ({ ...c, pointsTo: points }))
                      }
                    />
                    To {points}
                  </label>
                ))}
                <label className="play__choice">
                  <input
                    type="checkbox"
                    checked={values.winByTwo}
                    onChange={(event) =>
                      setValues((c) => ({
                        ...c,
                        winByTwo: event.target.checked,
                      }))
                    }
                  />
                  Win by 2
                </label>
              </div>
            </fieldset>

            <fieldset className="play__games">
              <legend className="field__label">Game scores</legend>
              {values.games.map((game, index) => (
                <div className="play__game" key={index}>
                  <span className="play__game-number">Game {index + 1}</span>
                  <input
                    type="text"
                    inputMode="numeric"
                    aria-label={`Game ${index + 1}, Player 1 score`}
                    value={game.a}
                    onChange={setGame(index, 'a')}
                    maxLength={2}
                  />
                  <span aria-hidden="true">–</span>
                  <input
                    type="text"
                    inputMode="numeric"
                    aria-label={`Game ${index + 1}, Player 2 score`}
                    value={game.b}
                    onChange={setGame(index, 'b')}
                    maxLength={2}
                  />
                  {values.games.length > 1 && (
                    <button
                      type="button"
                      className="play__remove"
                      onClick={() => removeGame(index)}
                      aria-label={`Remove game ${index + 1}`}
                    >
                      ✕
                    </button>
                  )}
                </div>
              ))}
              {values.games.length < MAX_GAMES && (
                <button type="button" className="play__add" onClick={addGame}>
                  + Add game
                </button>
              )}
              {errors.games && (
                <p className="field__error" role="alert">
                  {errors.games}
                </p>
              )}
              {winsA + winsB > 0 && (
                <p className="muted" aria-live="polite">
                  Games won: {winsA}–{winsB}
                </p>
              )}
            </fieldset>

            <Honeypot value={website} onChange={setWebsite} />

            {status === 'failed' && (
              <p className="play__failed" role="alert">
                Sorry, we could not save the game. Please check your connection
                and try again.
              </p>
            )}

            <button
              type="submit"
              className="button play__submit"
              disabled={status === 'sending'}
            >
              {status === 'sending' ? 'Saving…' : 'Save game'}
            </button>
          </form>
        </AsyncState>
      )}
    </div>
  )
}

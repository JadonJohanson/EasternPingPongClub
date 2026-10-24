import { useState } from 'react'
import { filterPlayers } from '../lib/search.js'
import './FormField.css'
import './PlayerPicker.css'

const MAX_SUGGESTIONS = 6

// Type-ahead for choosing who played. The visitor types a few letters, taps a
// suggestion, and that player is chosen. If the name is not a member, a button
// offers to use what was typed as a guest.
//
//   value:    { playerId, guestName }   (one of the two is filled in, or neither)
//   onChange: called with a new value
//   players:  [{ id, display_name }]
//   exclude:  a player id to hide (the opponent), so you cannot pick them twice
export default function PlayerPicker({
  id,
  label,
  players,
  value,
  onChange,
  exclude,
  error,
}) {
  // What is typed in the box while searching.
  const [text, setText] = useState('')

  const chosenPlayer = players.find((p) => p.id === value.playerId)
  const chosenName = chosenPlayer?.display_name ?? value.guestName

  // Once somebody is chosen, show them with a "Change" button instead.
  if (chosenName) {
    return (
      <div className="picker">
        <span className="field__label" id={`${id}-label`}>
          {label}
        </span>
        <div className="picker__chosen">
          <span>
            {chosenName}
            {!chosenPlayer && <span className="muted"> (guest)</span>}
          </span>
          <button
            type="button"
            className="picker__change"
            onClick={() => {
              setText('')
              onChange({ playerId: '', guestName: '' })
            }}
            aria-label={`Change ${label}`}
          >
            Change
          </button>
        </div>
        {error && (
          <p className="field__error" role="alert">
            {error}
          </p>
        )}
      </div>
    )
  }

  const typed = text.trim()
  const matches = typed
    ? filterPlayers(
        players.filter((p) => p.id !== exclude),
        typed,
      ).slice(0, MAX_SUGGESTIONS)
    : []

  return (
    <div className="picker">
      <label htmlFor={id} className="field__label">
        {label}
      </label>
      <input
        id={id}
        type="text"
        value={text}
        onChange={(event) => setText(event.target.value)}
        placeholder="Start typing a name"
        autoComplete="off"
        aria-invalid={Boolean(error)}
      />

      {typed && (
        <ul className="picker__options">
          {matches.map((player) => (
            <li key={player.id}>
              <button
                type="button"
                onClick={() => onChange({ playerId: player.id, guestName: '' })}
              >
                {player.display_name}
              </button>
            </li>
          ))}
          {/* Always offered, so a non-member can still be entered. */}
          <li>
            <button
              type="button"
              className="picker__guest"
              onClick={() => onChange({ playerId: '', guestName: typed })}
            >
              Use “{typed}” as a guest (not a member yet)
            </button>
          </li>
        </ul>
      )}
      {error && (
        <p className="field__error" role="alert">
          {error}
        </p>
      )}
    </div>
  )
}

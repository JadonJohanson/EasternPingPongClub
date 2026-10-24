// Rules for the Play form. They mirror the database checks in the matches
// migration (`match_games_score_valid`, guest name length, no self-play, ...)
// so players get a friendly message right away. The database still enforces
// them, so nobody can skip these checks by editing the page.

export const POINTS_OPTIONS = [11, 21]
export const MAX_GAMES = 9

// Is this a finished, legal score for one game? Same logic as the SQL check:
// the winner has exactly `pointsTo` points and the loser fewer (with "win by 2"
// the loser has at most pointsTo - 2); past the target (win by 2 only) the game
// ends on a 2-point gap, like 12-10 or 23-21.
export function isValidGame(a, b, pointsTo, winByTwo) {
  if (!Number.isInteger(a) || !Number.isInteger(b)) return false
  if (a < 0 || b < 0 || a > 99 || b > 99) return false
  const high = Math.max(a, b)
  const low = Math.min(a, b)
  if (high === pointsTo && low <= pointsTo - (winByTwo ? 2 : 1)) return true
  return winByTwo && high > pointsTo && high - low === 2
}

// Turns what was typed ("11", " 9", "") into a number, or null if blank or not
// a whole number.
export function parseScore(text) {
  const trimmed = String(text).trim()
  return /^[0-9]{1,2}$/.test(trimmed) ? Number(trimmed) : null
}

// A game row is "blank" when both boxes are empty; blank rows are ignored.
function isBlank(game) {
  return String(game.a).trim() === '' && String(game.b).trim() === ''
}

// The rows that were actually filled in, as numbers (null where unreadable).
export function filledGames(games) {
  return games
    .filter((game) => !isBlank(game))
    .map((game) => ({ a: parseScore(game.a), b: parseScore(game.b) }))
}

// Who won more games? Returns { winsA, winsB } counting only valid games.
export function tally(games, pointsTo, winByTwo) {
  let winsA = 0
  let winsB = 0
  for (const game of filledGames(games)) {
    if (!isValidGame(game.a, game.b, pointsTo, winByTwo)) continue
    if (game.a > game.b) winsA++
    else winsB++
  }
  return { winsA, winsB }
}

// A "side" looks like { playerId: 'uuid' | '', guestName: 'text' }.
// Exactly one of the two should be filled in.
function sideProblem(side) {
  const guest = side.guestName.trim()
  if (side.playerId && guest) return 'Choose a player or a guest, not both.'
  if (!side.playerId && !guest) return 'Please choose a player.'
  if (guest.length > 80) return 'Please use 80 characters or fewer.'
  return null
}

// Returns an object with a message per problem; empty means valid.
//   values: { a, b, pointsTo, winByTwo, games: [{ a: '11', b: '7' }, ...] }
export function validateMatch(values) {
  const errors = {}

  const problemA = sideProblem(values.a)
  if (problemA) errors.a = problemA
  const problemB = sideProblem(values.b)
  if (problemB) errors.b = problemB

  if (!errors.a && !errors.b) {
    if (values.a.playerId && values.a.playerId === values.b.playerId) {
      errors.b = 'A player cannot play themselves.'
    } else if (!values.a.playerId && !values.b.playerId) {
      // Guest vs guest would create no stats for any member.
      errors.b = 'At least one side must be a club member.'
    }
  }

  const games = filledGames(values.games)
  if (games.length === 0) {
    errors.games = 'Please enter at least one game score.'
  } else {
    const badIndex = games.findIndex(
      (game) => !isValidGame(game.a, game.b, values.pointsTo, values.winByTwo),
    )
    if (badIndex >= 0) {
      const target = values.winByTwo
        ? `${values.pointsTo}, win by 2`
        : `${values.pointsTo}`
      errors.games = `Game ${badIndex + 1} is not a finished score for a game to ${target}.`
    } else {
      const { winsA, winsB } = tally(
        values.games,
        values.pointsTo,
        values.winByTwo,
      )
      if (winsA === winsB) {
        errors.games = 'The match is tied. Add the deciding game.'
      }
    }
  }

  return errors
}

// Builds the rows to send: one match row and its game rows (numbered 1, 2, ...).
export function buildMatch(values) {
  const side = (s) => ({
    player: s.playerId || null,
    guest: s.playerId ? null : s.guestName.trim(),
  })
  const a = side(values.a)
  const b = side(values.b)
  return {
    match: {
      match_type: 'casual',
      player_a_id: a.player,
      guest_a_name: a.guest,
      player_b_id: b.player,
      guest_b_name: b.guest,
      points_to: values.pointsTo,
      win_by_two: values.winByTwo,
    },
    games: filledGames(values.games).map((game, index) => ({
      game_number: index + 1,
      points_to: values.pointsTo,
      win_by_two: values.winByTwo,
      score_a: game.a,
      score_b: game.b,
    })),
  }
}

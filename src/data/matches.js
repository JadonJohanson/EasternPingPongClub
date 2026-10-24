import { supabase } from '../lib/supabase.js'

// Saves a casual match and its games.
//
// Two steps, because the games need the match's id:
//   1. add the match row and ask for its new id back (everyone may read
//      matches, so `.select('id')` is allowed);
//   2. add the game rows for that id.
// The database only accepts game rows for a casual match created in the last
// 2 minutes, so this is the only moment games can be added.
//
// If step 2 fails, a match with no games is left behind. It has no winner, so
// the stats pages must ignore matches that have no games.
export async function submitCasualMatch({ match, games }) {
  const { data, error } = await supabase
    .from('matches')
    .insert(match)
    .select('id')
    .single()
  if (error) throw error

  const rows = games.map((game) => ({ ...game, match_id: data.id }))
  const { error: gamesError } = await supabase.from('match_games').insert(rows)
  if (gamesError) throw gamesError
}

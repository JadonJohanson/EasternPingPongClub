import { supabase } from '../lib/supabase.js'

// Gets every player, sorted by name. Only the id and name are public: emails
// and Eastern IDs are never stored in the players table.
export async function fetchPlayers() {
  const { data, error } = await supabase
    .from('players')
    .select('id, display_name')
    .order('display_name', { ascending: true })
  if (error) throw error
  return data
}

// Gets one player, or `null` if there is no player with that id.
export async function fetchPlayer(id) {
  const { data, error } = await supabase
    .from('players')
    .select('id, display_name')
    .eq('id', id)
    .maybeSingle() // null (not an error) when nothing matches
  if (error) {
    // A badly typed id (not a UUID) is just "no such player", not a failure.
    if (error.code === '22P02') return null
    throw error
  }
  return data
}

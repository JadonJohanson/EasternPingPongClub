import { supabase } from '../lib/supabase.js'

// Gets the next event that has not finished yet, or `null` if there is none.
//
// "Not finished" = it starts in the future, OR it has an end time that is still
// in the future (so a club night in progress still shows). Cancelled events
// are skipped.
export async function fetchNextEvent() {
  const now = new Date().toISOString()

  const { data, error } = await supabase
    .from('events')
    .select('id, title, description, location, starts_at, ends_at, kind')
    .eq('cancelled', false)
    .or(`starts_at.gte.${now},ends_at.gte.${now}`)
    .order('starts_at', { ascending: true })
    .limit(1)

  // Supabase returns errors instead of throwing them. We throw so that the
  // `useAsync` hook can show the error state.
  if (error) throw error
  return data[0] ?? null
}

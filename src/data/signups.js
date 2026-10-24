import { supabase } from '../lib/supabase.js'

// Sends one Sign Up form entry to the database.
//
// `signup` uses the database column names: name, email, eastern_id, skill_level.
//
// Note there is no `.select()` after the insert. Visitors are allowed to ADD
// signups but never to READ them (so emails and IDs cannot leak), and asking
// for the new row back counts as reading. Without `.select()`, Supabase just
// confirms it worked.
export async function submitSignup(signup) {
  const { error } = await supabase.from('signups').insert(signup)
  if (error) throw error
}

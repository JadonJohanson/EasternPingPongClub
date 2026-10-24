import { supabase } from '../lib/supabase.js'

// Sends one Contact form message to the database.
// `message` uses the database column names: name, email, message.
//
// Like signups, visitors can only ADD messages, never read them, so there is
// no `.select()` here (reading the new row back would be refused).
export async function sendContactMessage(message) {
  const { error } = await supabase.from('contact_messages').insert(message)
  if (error) throw error
}

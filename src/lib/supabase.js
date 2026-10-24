// The ONE place the website connects to Supabase (our database).
// Every page that needs data imports `supabase` from this file.
//
// The two values below come from a `.env` file on your computer (see
// `.env.example`) and, for the live site, from GitHub Actions variables.
// Vite only exposes variables whose names start with VITE_ to the browser.
//
// Both values are SAFE to be public: the "anon" key only lets visitors do what
// the database's security rules (RLS) allow. The secret "service-role" key must
// NEVER be put here, in `.env.example`, or anywhere in this repo.
import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

// True when both settings exist. Pages use this to show a helpful message
// instead of crashing when the site is run without a `.env` file.
export const isSupabaseConfigured = Boolean(url && anonKey)

// `null` when not configured, so nothing can accidentally talk to a wrong server.
export const supabase = isSupabaseConfigured ? createClient(url, anonKey) : null

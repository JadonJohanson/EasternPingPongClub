-- Structural safety checks that apply to the WHOLE database.
-- Run with: npx supabase test db   (needs Docker; CI runs it for you)
--
-- pgTAP basics: `plan(N)` says how many checks to expect, each check prints
-- "ok" or "not ok", and everything is rolled back at the end so tests never
-- leave data behind.

begin;
select plan(32);

-- 1. No table in the public schema may be missing Row Level Security.
--    When you add a table in a later migration, this test fails until RLS is on.
select is_empty(
  $$
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and not c.relrowsecurity
  $$,
  'every table in public has Row Level Security enabled'
);

-- 2-7. The exact table privileges each role has. This is the "grant" layer
--       that sits in front of the row policies. If someone grants more than
--       intended, these fail.
select table_privs_are('public', 'officers', 'anon', array[]::text[],
  'anon has no access to officers');
select table_privs_are('public', 'officers', 'authenticated', array['SELECT'],
  'authenticated can only read officers');

select table_privs_are('public', 'players', 'anon', array['SELECT'],
  'anon can only read players');
select table_privs_are('public', 'players', 'authenticated',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated can attempt every action on players (RLS limits it to officers)');

select table_privs_are('public', 'settings', 'anon', array['SELECT'],
  'anon can only read settings');
select table_privs_are('public', 'settings', 'authenticated',
  array['SELECT', 'UPDATE'],
  'authenticated can read and update settings, but never insert or delete');

select table_privs_are('public', 'matches', 'anon', array['SELECT'],
  'anon can only read matches at table level (inserts are limited to listed columns, below)');
select table_privs_are('public', 'matches', 'authenticated',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated can attempt every action on matches (RLS limits non-officers to casual inserts)');

select table_privs_are('public', 'match_games', 'anon', array['SELECT', 'INSERT'],
  'anon can read and add match games, never edit or delete them');
select table_privs_are('public', 'match_games', 'authenticated',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated can attempt every action on match_games (RLS limits non-officers)');

select table_privs_are('public', 'tournaments', 'anon', array['SELECT'],
  'anon can only read tournaments');
select table_privs_are('public', 'tournaments', 'authenticated',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated can attempt every action on tournaments (RLS limits it to officers)');
select table_privs_are('public', 'tournament_entries', 'anon', array['SELECT'],
  'anon can only read tournament entries');
select table_privs_are('public', 'tournament_entries', 'authenticated',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated can attempt every action on tournament entries (RLS limits it to officers)');
select table_privs_are('public', 'rating_history', 'anon', array['SELECT'],
  'anon can only read rating history');
select table_privs_are('public', 'rating_history', 'authenticated',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated can attempt every action on rating history (RLS limits it to officers)');

select table_privs_are('public', 'events', 'anon', array['SELECT'],
  'anon can only read events');
select table_privs_are('public', 'events', 'authenticated',
  array['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated can attempt every action on events (RLS limits it to officers)');
select table_privs_are('public', 'signups', 'anon', array[]::text[],
  'anon has no table-level access to signups (only the form columns, below)');
select table_privs_are('public', 'signups', 'authenticated',
  array['SELECT', 'UPDATE', 'DELETE'],
  'authenticated can attempt to read, edit and delete signups (RLS limits it to officers)');
select table_privs_are('public', 'contact_messages', 'anon', array[]::text[],
  'anon has no table-level access to contact messages (only the form columns, below)');
select table_privs_are('public', 'contact_messages', 'authenticated',
  array['SELECT', 'DELETE'],
  'authenticated can attempt to read and delete contact messages (RLS limits it to officers)');
select ok(
  has_column_privilege('anon', 'public.signups', 'name', 'INSERT')
  and has_column_privilege('anon', 'public.signups', 'email', 'INSERT')
  and has_column_privilege('anon', 'public.signups', 'eastern_id', 'INSERT')
  and has_column_privilege('anon', 'public.signups', 'skill_level', 'INSERT')
  and has_column_privilege('anon', 'public.contact_messages', 'message', 'INSERT'),
  'anon may fill in the form columns of signups and contact_messages'
);
select ok(
  not has_column_privilege('anon', 'public.signups', 'created_at', 'INSERT')
  and not has_column_privilege('anon', 'public.signups', 'id', 'INSERT')
  and not has_column_privilege('anon', 'public.signups', 'email', 'SELECT')
  and not has_column_privilege('anon', 'public.signups', 'eastern_id', 'SELECT')
  and not has_column_privilege('anon', 'public.contact_messages', 'email', 'SELECT'),
  'anon can never read signup emails or Eastern IDs, or contact emails, and cannot set id or created_at'
);

-- Column-level insert rights for anon on matches: the Play form's columns yes,
-- the server-controlled columns no.
select ok(
  has_column_privilege('anon', 'public.matches', 'guest_b_name', 'INSERT')
  and has_column_privilege('anon', 'public.matches', 'player_a_id', 'INSERT')
  and has_column_privilege('anon', 'public.matches', 'points_to', 'INSERT')
  and has_column_privilege('anon', 'public.matches', 'win_by_two', 'INSERT')
  and has_column_privilege('anon', 'public.matches', 'played_at', 'INSERT'),
  'anon may insert the Play form columns of matches'
);
select ok(
  not has_column_privilege('anon', 'public.matches', 'id', 'INSERT'),
  'anon may not choose a match id'
);
select ok(
  not has_column_privilege('anon', 'public.matches', 'created_at', 'INSERT'),
  'anon may not set created_at'
);
select ok(
  not has_column_privilege('anon', 'public.matches', 'tournament_id', 'INSERT'),
  'anon may not set tournament_id'
);

-- Next: Visitors may not create anything in the private helper schema.
select is(
  has_schema_privilege('anon', 'private', 'CREATE'),
  false,
  'anon cannot create objects in the private schema'
);
select is(
  has_schema_privilege('authenticated', 'private', 'CREATE'),
  false,
  'authenticated cannot create objects in the private schema'
);

-- Supabase's own automatic-RLS helper must not be callable by visitors. (It may
-- not exist on a plain local database, in which case there is nothing to lock.)
select is(
  coalesce(
    has_function_privilege('anon', to_regprocedure('public.rls_auto_enable()'), 'EXECUTE')
    or has_function_privilege('authenticated', to_regprocedure('public.rls_auto_enable()'), 'EXECUTE'),
    false
  ),
  false,
  'anon and authenticated cannot execute public.rls_auto_enable()'
);

select * from finish();
rollback;

-- Structural safety checks that apply to the WHOLE database.
-- Run with: npx supabase test db   (needs Docker; CI runs it for you)
--
-- pgTAP basics: `plan(N)` says how many checks to expect, each check prints
-- "ok" or "not ok", and everything is rolled back at the end so tests never
-- leave data behind.

begin;
select plan(18);

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

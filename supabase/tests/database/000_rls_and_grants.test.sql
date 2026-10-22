-- Structural safety checks that apply to the WHOLE database.
-- Run with: npx supabase test db   (needs Docker; CI runs it for you)
--
-- pgTAP basics: `plan(N)` says how many checks to expect, each check prints
-- "ok" or "not ok", and everything is rolled back at the end so tests never
-- leave data behind.

begin;
select plan(9);

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

-- 8-9. Visitors may not create anything in the private helper schema.
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

select * from finish();
rollback;

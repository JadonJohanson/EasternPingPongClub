-- Foundation: players, officers, settings, and the officer check.
--
-- RULES USED IN EVERY MIGRATION IN THIS PROJECT
--   1. Row Level Security (RLS) is turned ON for every table. With RLS on and
--      no matching policy, the answer is "no rows / not allowed".
--   2. This Supabase project has "Automatically expose new tables" switched
--      OFF, so the Data API (what the website talks to) cannot touch a table
--      until we GRANT it. Every table therefore starts with a REVOKE ALL and
--      then grants only what is needed. Grants decide which KINDS of action a
--      role may attempt; policies then decide which ROWS it may touch.
--      (Revoking first also makes this file behave the same on a local
--      database, where Supabase grants everything by default.)
--   3. "Is this person an officer?" is answered by looking them up in the
--      `officers` table, never by reading user metadata, because users can edit
--      their own metadata.
--
-- The roles you will see:
--   anon           a visitor who is not logged in
--   authenticated  a logged-in user (an officer, or anyone else with a login)

-- ---------------------------------------------------------------------------
-- A private schema for helper functions. It is NOT in the list of schemas the
-- Data API exposes (see [api] schemas in supabase/config.toml), so nobody can
-- call these functions directly from the website.
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

-- ---------------------------------------------------------------------------
-- officers: the logins that are allowed to manage the club's data.
-- Rows are added by hand (SQL editor / migration), never through the website.
-- ---------------------------------------------------------------------------
create table public.officers (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

comment on table public.officers is
  'Logins allowed to manage club data. Managed by hand; the Data API can only read your own row.';

alter table public.officers enable row level security;

revoke all on public.officers from anon, authenticated;
-- Read only. Nobody can insert, update or delete officers through the Data API.
grant select on public.officers to authenticated;

-- A logged-in user may read only their OWN row, so the website can ask
-- "am I an officer?" without being able to list the other officers.
create policy "officers: read own row"
  on public.officers
  for select
  to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- private.is_officer(): true when the current logged-in user is in `officers`.
--
-- SECURITY DEFINER means it runs with its owner's rights, so it can read the
-- `officers` table even though ordinary users can only see their own row.
-- `set search_path = ''` is a safety measure for security definer functions:
-- everything inside must be written with its schema name (public.officers).
-- ---------------------------------------------------------------------------
create function private.is_officer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.officers
    where user_id = (select auth.uid())
  );
$$;

revoke all on function private.is_officer() from public;
grant execute on function private.is_officer() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- players: the one shared list of people. Every match, rating and profile
-- refers to a player by this id.
-- ---------------------------------------------------------------------------
create table public.players (
  id           uuid primary key default gen_random_uuid(),
  display_name text not null,
  created_at   timestamptz not null default now(),

  -- Names must be 1 to 80 characters with no leading or trailing spaces.
  constraint players_display_name_valid check (
    display_name = btrim(display_name)
    and char_length(display_name) between 1 and 80
  )
);

comment on table public.players is
  'Every club member we track. Public to read; only officers can change it.';

alter table public.players enable row level security;

revoke all on public.players from anon, authenticated;
grant select on public.players to anon, authenticated;
grant insert, update, delete on public.players to authenticated;

create policy "players: anyone can read"
  on public.players
  for select
  to anon, authenticated
  using (true);

-- `with check` is the rule a NEW or CHANGED row must satisfy.
-- `using` is the rule for which EXISTING rows you may touch.
-- Wrapping the function call in (select ...) lets Postgres evaluate it once
-- per query instead of once per row.
create policy "players: officers can add"
  on public.players
  for insert
  to authenticated
  with check ((select private.is_officer()));

create policy "players: officers can edit"
  on public.players
  for update
  to authenticated
  using ((select private.is_officer()))
  with check ((select private.is_officer()));

create policy "players: officers can delete"
  on public.players
  for delete
  to authenticated
  using ((select private.is_officer()));

-- ---------------------------------------------------------------------------
-- settings: club-wide numbers. Exactly ONE row ever exists: `id` can only be
-- true, and it is the primary key, so a second row is impossible.
-- (Elo details such as a higher K for new players are added in Phase 8.)
-- ---------------------------------------------------------------------------
create table public.settings (
  id              boolean primary key default true,
  starting_rating integer not null default 1000,
  k_factor        integer not null default 32,

  constraint settings_single_row check (id),
  constraint settings_starting_rating_valid check (starting_rating between 100 and 5000),
  constraint settings_k_factor_valid check (k_factor between 1 and 200)
);

comment on table public.settings is
  'Single-row table of club-wide settings (starting rating, K factor).';

insert into public.settings default values;

alter table public.settings enable row level security;

revoke all on public.settings from anon, authenticated;
-- No insert or delete: the single row is created above and must stay.
grant select on public.settings to anon, authenticated;
grant update on public.settings to authenticated;

create policy "settings: anyone can read"
  on public.settings
  for select
  to anon, authenticated
  using (true);

create policy "settings: officers can edit"
  on public.settings
  for update
  to authenticated
  using ((select private.is_officer()))
  with check ((select private.is_officer()));

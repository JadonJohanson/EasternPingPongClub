-- Events (the schedule), signups (the Sign Up form) and contact messages (the
-- Contact form).
--
--   events            public to read, officers write. The Home page shows the
--                     next upcoming one; the Schedule page lists them all.
--   signups           visitors can ADD a row (the Sign Up form) but can never
--                     read any. Only officers can read them. They hold school
--                     emails and Eastern ID numbers, so they must never be public.
--   contact_messages  same idea for the Contact form.
--
-- Same rules as before: RLS on, revoke all, exact grants, one policy per action.

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------
create table public.events (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  description   text,
  location      text,
  starts_at     timestamptz not null,
  ends_at       timestamptz,
  kind          text not null default 'other',
  -- Optional link to the tournament played at this event. If the tournament is
  -- ever deleted (drafts only) the event simply stays without a link.
  tournament_id uuid references public.tournaments (id) on delete set null,
  cancelled     boolean not null default false,
  created_at    timestamptz not null default now(),

  constraint events_title_valid check (title = btrim(title) and char_length(title) between 1 and 120),
  constraint events_description_valid check (description is null or char_length(description) <= 2000),
  constraint events_location_valid check (location is null or char_length(location) <= 200),
  constraint events_kind_valid check (kind in ('practice', 'tournament', 'social', 'other')),
  constraint events_end_after_start check (ends_at is null or ends_at > starts_at)
);

comment on table public.events is
  'The club schedule. Public to read; only officers can change it.';

create index events_starts_at_idx on public.events (starts_at);
create index events_tournament_idx on public.events (tournament_id);

alter table public.events enable row level security;

revoke all on public.events from anon, authenticated;
grant select on public.events to anon, authenticated;
grant insert, update, delete on public.events to authenticated;

create policy "events: anyone can read"
  on public.events for select to anon, authenticated
  using (true);

create policy "events: officers can add"
  on public.events for insert to authenticated
  with check ((select private.is_officer()));

create policy "events: officers can edit"
  on public.events for update to authenticated
  using ((select private.is_officer()))
  with check ((select private.is_officer()));

create policy "events: officers can delete"
  on public.events for delete to authenticated
  using ((select private.is_officer()));

-- ---------------------------------------------------------------------------
-- signups: the Sign Up form
-- ---------------------------------------------------------------------------
create table public.signups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  email       text not null,
  -- Eastern ID: exactly 8 digits. Kept as text so a leading zero is not lost.
  eastern_id  text not null,
  skill_level text not null,
  created_at  timestamptz not null default now(),

  constraint signups_name_valid check (name = btrim(name) and char_length(name) between 1 and 100),
  -- A school address: name@easternct.edu or name@my.easternct.edu.
  constraint signups_email_valid check (
    char_length(email) <= 254
    and email ~* '^[^@[:space:]]+@(my\.)?easternct\.edu$'
  ),
  constraint signups_eastern_id_valid check (eastern_id ~ '^[0-9]{8}$'),
  constraint signups_skill_level_valid check (
    skill_level in ('beginner', 'intermediate', 'advanced', 'expert', 'master')
  )
);

comment on table public.signups is
  'Sign Up form entries. Contains school emails and Eastern IDs: visitors can only add rows; only officers can read.';

alter table public.signups enable row level security;

revoke all on public.signups from anon, authenticated;
-- Visitors may add a row, filling in only the four form fields (they cannot
-- choose the id or the time). There is NO select grant for anon: nobody can
-- read signups through the website, so emails and IDs cannot leak.
grant insert (name, email, eastern_id, skill_level) on public.signups to anon, authenticated;
grant select, update, delete on public.signups to authenticated;

-- A policy that is just "true" would work, but Supabase's checker flags those.
-- `created_at = now()` is always true for a normal insert (created_at is never
-- supplied, so it takes its default of now()), and it documents the intent: the
-- time is set by the server, not the visitor.
create policy "signups: anyone can submit"
  on public.signups for insert to anon, authenticated
  with check (created_at = now());

create policy "signups: officers can read"
  on public.signups for select to authenticated
  using ((select private.is_officer()));

create policy "signups: officers can edit"
  on public.signups for update to authenticated
  using ((select private.is_officer()))
  with check ((select private.is_officer()));

create policy "signups: officers can delete"
  on public.signups for delete to authenticated
  using ((select private.is_officer()));

-- ---------------------------------------------------------------------------
-- contact_messages: the Contact form
-- ---------------------------------------------------------------------------
create table public.contact_messages (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  email      text not null,
  message    text not null,
  created_at timestamptz not null default now(),

  constraint contact_name_valid check (name = btrim(name) and char_length(name) between 1 and 100),
  constraint contact_email_valid check (
    char_length(email) <= 254 and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  constraint contact_message_valid check (message = btrim(message) and char_length(message) between 1 and 2000)
);

comment on table public.contact_messages is
  'Contact form messages. Visitors can only add rows; only officers can read or delete.';

alter table public.contact_messages enable row level security;

revoke all on public.contact_messages from anon, authenticated;
grant insert (name, email, message) on public.contact_messages to anon, authenticated;
grant select, delete on public.contact_messages to authenticated;

create policy "contact_messages: anyone can send"
  on public.contact_messages for insert to anon, authenticated
  with check (created_at = now());

create policy "contact_messages: officers can read"
  on public.contact_messages for select to authenticated
  using ((select private.is_officer()));

create policy "contact_messages: officers can delete"
  on public.contact_messages for delete to authenticated
  using ((select private.is_officer()));

-- Tournaments: the tournament itself, who entered (with the seeding snapshot),
-- rating history, and walkovers on matches.
--
--   tournaments         one row per tournament. Officers create and run them.
--   tournament_entries  who is in a tournament, plus a SNAPSHOT of each
--                       player's rating and seed taken when the bracket was
--                       made, so later rating changes never rewrite history.
--   rating_history      a player's club rating after each tournament (for the
--                       profile chart). Filled by the Elo replay in Phase 8.
--   matches             gains a real foreign key to tournaments, plus walkover
--                       columns (forfeits and withdrawals have no games).
--
-- The bracket drawing/advancing itself will be handled by brackets-manager.js
-- in Phase 7. When a bracket match finishes, a row is written to `matches`.
--
-- Same rules as before: RLS on, revoke all, exact grants, one policy per action.

-- ---------------------------------------------------------------------------
-- tournaments
-- ---------------------------------------------------------------------------
create table public.tournaments (
  id                uuid primary key default gen_random_uuid(),
  name              text not null,
  format            text not null default 'single_elimination',
  seeding_method    text not null default 'elo',
  -- draft -> in_progress -> complete. A complete tournament is locked until an
  -- officer deliberately reopens it (complete -> in_progress) to fix a result.
  status            text not null default 'draft',
  -- Default scoring rule for this tournament's matches (see matches).
  points_to         smallint not null default 11,
  win_by_two        boolean not null default true,
  third_place_match boolean not null default false,
  held_on           date,
  created_at        timestamptz not null default now(),
  completed_at      timestamptz,

  constraint tournaments_name_valid check (
    name = btrim(name) and char_length(name) between 1 and 120
  ),
  constraint tournaments_format_valid check (format in ('single_elimination', 'double_elimination')),
  constraint tournaments_seeding_valid check (seeding_method in ('elo', 'random')),
  constraint tournaments_status_valid check (status in ('draft', 'in_progress', 'complete')),
  constraint tournaments_points_to_valid check (points_to in (11, 21))
);

comment on table public.tournaments is
  'Officer-run tournaments. Public to read; only officers can change them.';

alter table public.tournaments enable row level security;

revoke all on public.tournaments from anon, authenticated;
grant select on public.tournaments to anon, authenticated;
grant insert, update, delete on public.tournaments to authenticated;

create policy "tournaments: anyone can read"
  on public.tournaments for select to anon, authenticated
  using (true);

create policy "tournaments: officers can add"
  on public.tournaments for insert to authenticated
  with check ((select private.is_officer()));

create policy "tournaments: officers can edit"
  on public.tournaments for update to authenticated
  using ((select private.is_officer()))
  with check ((select private.is_officer()));

-- Only a draft (not yet started) tournament can be deleted. Once it has
-- started or finished it is kept as a record.
create policy "tournaments: officers can delete drafts"
  on public.tournaments for delete to authenticated
  using ((select private.is_officer()) and status = 'draft');

-- A trigger runs code automatically when a row changes. This one protects
-- the tournament life cycle, which a plain CHECK cannot do because it needs to
-- compare the OLD row with the NEW row.
create function private.tournaments_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'draft' then
      raise exception 'a new tournament must start as a draft' using errcode = '55000';
    end if;
  else
    -- Allowed status moves: draft -> in_progress -> complete, and
    -- complete -> in_progress (reopen to correct a result).
    if new.status <> old.status
       and (old.status, new.status) not in (
         ('draft', 'in_progress'), ('in_progress', 'complete'), ('complete', 'in_progress')
       ) then
      raise exception 'tournament status cannot go from % to %', old.status, new.status
        using errcode = '55000';
    end if;
    -- Once started, the setup is locked.
    if old.status <> 'draft'
       and (new.format, new.seeding_method, new.third_place_match, new.points_to, new.win_by_two)
           is distinct from
           (old.format, old.seeding_method, old.third_place_match, old.points_to, old.win_by_two) then
      raise exception 'tournament setup is locked once it has started' using errcode = '55000';
    end if;
  end if;

  -- completed_at follows the status automatically.
  new.completed_at := case
    when new.status = 'complete' then coalesce(new.completed_at, now())
    else null
  end;
  return new;
end
$$;

revoke all on function private.tournaments_guard() from public;

create trigger tournaments_guard
  before insert or update on public.tournaments
  for each row execute function private.tournaments_guard();

-- ---------------------------------------------------------------------------
-- Helper checks used by policies. They run as the logged-in user (not
-- security definer); officers can already read the tables they look at.
-- ---------------------------------------------------------------------------
-- True when there is no tournament (a casual match) or it is not complete.
create function private.tournament_is_open(tid uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select tid is null
      or exists (select 1 from public.tournaments t where t.id = tid and t.status <> 'complete');
$$;

create function private.match_is_editable(mid uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.matches m
    where m.id = mid and private.tournament_is_open(m.tournament_id)
  );
$$;

revoke all on function private.tournament_is_open(uuid) from public;
revoke all on function private.match_is_editable(uuid) from public;
grant execute on function private.tournament_is_open(uuid) to authenticated;
grant execute on function private.match_is_editable(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- tournament_entries
-- ---------------------------------------------------------------------------
create table public.tournament_entries (
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  player_id     uuid not null references public.players (id) on delete restrict,
  -- Snapshot taken when the bracket is created (Phase 7). Null while drafting.
  seed          smallint,
  seed_rating   integer,
  is_new        boolean not null default false,   -- no rating yet: shown as "new"
  -- The stored result of the random draw: the shuffle for random seeding, and
  -- the tie-break when two players have the same rating.
  random_order  integer,
  status        text not null default 'active',   -- 'withdrawn' after a withdrawal
  final_place   smallint,

  primary key (tournament_id, player_id),

  constraint tournament_entries_seed_valid check (seed is null or seed >= 1),
  constraint tournament_entries_rating_valid check (seed_rating is null or seed_rating between 0 and 10000),
  constraint tournament_entries_status_valid check (status in ('active', 'withdrawn')),
  constraint tournament_entries_place_valid check (final_place is null or final_place >= 1),

  -- Seeds are unique within a tournament. DEFERRABLE lets two players swap
  -- seeds in one UPDATE (drag-to-swap) without a temporary clash.
  constraint tournament_entries_seed_unique unique (tournament_id, seed)
    deferrable initially immediate
);

comment on table public.tournament_entries is
  'Players in a tournament, with the rating and seed snapshot from bracket creation.';

create index tournament_entries_player_idx on public.tournament_entries (player_id);

alter table public.tournament_entries enable row level security;

revoke all on public.tournament_entries from anon, authenticated;
grant select on public.tournament_entries to anon, authenticated;
grant insert, update, delete on public.tournament_entries to authenticated;

create policy "tournament_entries: anyone can read"
  on public.tournament_entries for select to anon, authenticated
  using (true);

-- Players can only be added or removed while the tournament is a draft.
create policy "tournament_entries: officers can add to a draft"
  on public.tournament_entries for insert to authenticated
  with check (
    (select private.is_officer())
    and exists (select 1 from public.tournaments t
                where t.id = tournament_entries.tournament_id and t.status = 'draft')
  );

-- Edits (withdrawing a player, final place) are fine until the tournament is
-- complete. The trigger below additionally locks the seeding snapshot at start.
create policy "tournament_entries: officers can edit"
  on public.tournament_entries for update to authenticated
  using ((select private.is_officer()) and (select private.tournament_is_open(tournament_id)))
  with check ((select private.is_officer()) and (select private.tournament_is_open(tournament_id)));

create policy "tournament_entries: officers can remove from a draft"
  on public.tournament_entries for delete to authenticated
  using (
    (select private.is_officer())
    and exists (select 1 from public.tournaments t
                where t.id = tournament_entries.tournament_id and t.status = 'draft')
  );

create function private.tournament_entries_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.tournament_id <> old.tournament_id or new.player_id <> old.player_id then
    raise exception 'an entry cannot be moved to another tournament or player' using errcode = '55000';
  end if;
  if (new.seed, new.seed_rating, new.is_new, new.random_order)
       is distinct from (old.seed, old.seed_rating, old.is_new, old.random_order)
     and exists (select 1 from public.tournaments t
                 where t.id = new.tournament_id and t.status <> 'draft') then
    raise exception 'seeding is locked once the tournament has started' using errcode = '55000';
  end if;
  return new;
end
$$;

revoke all on function private.tournament_entries_guard() from public;

create trigger tournament_entries_guard
  before update on public.tournament_entries
  for each row execute function private.tournament_entries_guard();

-- ---------------------------------------------------------------------------
-- rating_history: one row per player per tournament they played.
-- ---------------------------------------------------------------------------
create table public.rating_history (
  player_id     uuid not null references public.players (id) on delete cascade,
  tournament_id uuid not null references public.tournaments (id) on delete cascade,
  rating_before integer not null,
  rating_after  integer not null,
  created_at    timestamptz not null default now(),

  primary key (player_id, tournament_id),

  constraint rating_history_range check (
    rating_before between 0 and 10000 and rating_after between 0 and 10000
  )
);

comment on table public.rating_history is
  'Club rating after each tournament, for profile charts. Written by the Elo replay (officers only).';

create index rating_history_tournament_idx on public.rating_history (tournament_id);

alter table public.rating_history enable row level security;

revoke all on public.rating_history from anon, authenticated;
grant select on public.rating_history to anon, authenticated;
grant insert, update, delete on public.rating_history to authenticated;

create policy "rating_history: anyone can read"
  on public.rating_history for select to anon, authenticated
  using (true);

create policy "rating_history: officers can add"
  on public.rating_history for insert to authenticated
  with check ((select private.is_officer()));

create policy "rating_history: officers can edit"
  on public.rating_history for update to authenticated
  using ((select private.is_officer()))
  with check ((select private.is_officer()));

create policy "rating_history: officers can delete"
  on public.rating_history for delete to authenticated
  using ((select private.is_officer()));

-- ---------------------------------------------------------------------------
-- matches: link to tournaments, walkovers, and the tournament lock
-- ---------------------------------------------------------------------------
-- A walkover (forfeit or withdrawal) has no games. `walkover_winner` says which
-- side advances: 'a' or 'b'. Normal matches leave both walkover columns alone.
alter table public.matches
  add column is_walkover     boolean not null default false,
  add column walkover_winner text;

alter table public.matches
  add constraint matches_walkover_shape check (
    -- coalesce: a missing winner makes `in` return NULL, which a CHECK would let through.
    (is_walkover and coalesce(walkover_winner in ('a', 'b'), false) and match_type = 'tournament')
    or (not is_walkover and walkover_winner is null)
  );

alter table public.matches
  add constraint matches_tournament_fkey
    foreign key (tournament_id) references public.tournaments (id) on delete restrict;

-- Both players of a tournament match must be entered in that tournament. When
-- tournament_id is null (casual) these foreign keys are skipped automatically.
alter table public.matches
  add constraint matches_player_a_entered_fkey
    foreign key (tournament_id, player_a_id)
    references public.tournament_entries (tournament_id, player_id) on delete restrict,
  add constraint matches_player_b_entered_fkey
    foreign key (tournament_id, player_b_id)
    references public.tournament_entries (tournament_id, player_id) on delete restrict;

create index matches_entry_a_idx on public.matches (tournament_id, player_a_id);
create index matches_entry_b_idx on public.matches (tournament_id, player_b_id);

-- Officers may change matches only while their tournament is not complete.
alter policy "matches: officers can add" on public.matches
  with check ((select private.is_officer()) and (select private.tournament_is_open(tournament_id)));
alter policy "matches: officers can edit" on public.matches
  using ((select private.is_officer()) and (select private.tournament_is_open(tournament_id)))
  with check ((select private.is_officer()) and (select private.tournament_is_open(tournament_id)));
alter policy "matches: officers can delete" on public.matches
  using ((select private.is_officer()) and (select private.tournament_is_open(tournament_id)));

alter policy "match_games: officers can add" on public.match_games
  with check ((select private.is_officer()) and (select private.match_is_editable(match_id)));
alter policy "match_games: officers can edit" on public.match_games
  using ((select private.is_officer()) and (select private.match_is_editable(match_id)))
  with check ((select private.is_officer()) and (select private.match_is_editable(match_id)));
alter policy "match_games: officers can delete" on public.match_games
  using ((select private.is_officer()) and (select private.match_is_editable(match_id)));

-- A walkover must have no games, in both directions.
create function private.match_games_no_walkover()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (select 1 from public.matches m where m.id = new.match_id and m.is_walkover) then
    raise exception 'a walkover match cannot have games' using errcode = '55000';
  end if;
  return new;
end
$$;

create function private.matches_walkover_has_no_games()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_walkover and exists (select 1 from public.match_games g where g.match_id = new.id) then
    raise exception 'a match with games cannot be a walkover' using errcode = '55000';
  end if;
  return new;
end
$$;

revoke all on function private.match_games_no_walkover() from public;
revoke all on function private.matches_walkover_has_no_games() from public;

create trigger match_games_no_walkover
  before insert or update on public.match_games
  for each row execute function private.match_games_no_walkover();

create trigger matches_walkover_has_no_games
  before update on public.matches
  for each row execute function private.matches_walkover_has_no_games();

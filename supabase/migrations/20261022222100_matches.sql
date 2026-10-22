-- Matches and their games: casual and tournament results in ONE flat table.
--
--   matches       one row per match. `match_type` says 'casual' (entered by
--                 members on the Play page) or 'tournament' (entered by
--                 officers). Only tournament rows will ever feed Elo.
--   match_games   one row per game inside a match (11-7, 9-11, 11-8 ...).
--                 Who won the match is NOT stored; it is worked out from the
--                 games, so it can never disagree with them.
--
-- Each side of a match is EITHER a club player (player_*_id) OR a typed guest
-- name (guest_*_name). Guests never get a row in `players`.
--
-- Rules for everything below are the same as the foundation migration: RLS
-- on, revoke all, exact grants, then one policy per allowed action.

-- ---------------------------------------------------------------------------
-- matches
-- ---------------------------------------------------------------------------
create table public.matches (
  id            uuid primary key default gen_random_uuid(),
  match_type    text not null,
  -- Filled only for tournament matches. The foreign key to `tournaments` is
  -- added in step 2c, when that table exists.
  tournament_id uuid,
  player_a_id   uuid references public.players (id) on delete restrict,
  guest_a_name  text,
  player_b_id   uuid references public.players (id) on delete restrict,
  guest_b_name  text,
  -- Scoring rule for every game of this match: played to 11 or 21 points,
  -- and either "win by 2" (deuce) or first to the target wins outright.
  points_to     smallint not null default 11,
  win_by_two    boolean not null default true,
  played_at     timestamptz not null default now(),
  created_at    timestamptz not null default now(),

  constraint matches_points_to_valid check (points_to in (11, 21)),
  -- Lets match_games point at (id, points_to, win_by_two) so every game is
  -- guaranteed to use the same scoring rule as its match.
  constraint matches_id_rule_key unique (id, points_to, win_by_two),

  constraint matches_type_valid check (match_type in ('casual', 'tournament')),

  -- Casual: no tournament. Tournament: has a tournament and two real players.
  constraint matches_type_shape check (
    (match_type = 'casual' and tournament_id is null)
    or (match_type = 'tournament' and tournament_id is not null
        and player_a_id is not null and player_b_id is not null)
  ),

  -- Each side is exactly one of: a player, or a guest name.
  constraint matches_side_a_one_of check (num_nonnulls(player_a_id, guest_a_name) = 1),
  constraint matches_side_b_one_of check (num_nonnulls(player_b_id, guest_b_name) = 1),

  -- Guest names: 1 to 80 characters, no leading or trailing spaces.
  constraint matches_guest_a_name_valid check (
    guest_a_name is null
    or (guest_a_name = btrim(guest_a_name) and char_length(guest_a_name) between 1 and 80)
  ),
  constraint matches_guest_b_name_valid check (
    guest_b_name is null
    or (guest_b_name = btrim(guest_b_name) and char_length(guest_b_name) between 1 and 80)
  ),

  -- A player cannot play themselves, and a match needs at least one club
  -- player (guest vs guest would create no stats).
  constraint matches_no_self_play check (
    player_a_id is null or player_b_id is null or player_a_id <> player_b_id
  ),
  constraint matches_has_a_player check (
    player_a_id is not null or player_b_id is not null
  )
);

comment on table public.matches is
  'Casual and tournament matches (flat table). Winner is derived from match_games.';

-- Indexes make "all matches for this player" and "latest matches" fast.
create index matches_player_a_idx on public.matches (player_a_id);
create index matches_player_b_idx on public.matches (player_b_id);
create index matches_tournament_idx on public.matches (tournament_id);
create index matches_played_at_idx on public.matches (played_at desc);

alter table public.matches enable row level security;

revoke all on public.matches from anon, authenticated;
grant select on public.matches to anon, authenticated;
-- Visitors may add a match, but only these columns. They cannot choose the id,
-- the created_at time, or a tournament_id.
grant insert (match_type, player_a_id, guest_a_name, player_b_id, guest_b_name,
              points_to, win_by_two, played_at)
  on public.matches to anon;
-- Logged-in users get every column (RLS still limits non-officers to casual).
grant insert, update, delete on public.matches to authenticated;

create policy "matches: anyone can read"
  on public.matches
  for select
  to anon, authenticated
  using (true);

-- Public casual logging. The row must be a casual match, created right now
-- (created_at = now() is the default; a different value is refused, so nobody
-- can fake an "open window" below), and played within the last 30 days.
create policy "matches: anyone can add a casual match"
  on public.matches
  for insert
  to anon, authenticated
  with check (
    match_type = 'casual'
    and tournament_id is null
    and created_at = now()
    and played_at between now() - interval '30 days' and now() + interval '5 minutes'
  );

create policy "matches: officers can add"
  on public.matches
  for insert
  to authenticated
  with check ((select private.is_officer()));

create policy "matches: officers can edit"
  on public.matches
  for update
  to authenticated
  using ((select private.is_officer()))
  with check ((select private.is_officer()));

create policy "matches: officers can delete"
  on public.matches
  for delete
  to authenticated
  using ((select private.is_officer()));

-- ---------------------------------------------------------------------------
-- match_games
-- ---------------------------------------------------------------------------
create table public.match_games (
  match_id    uuid not null,
  game_number smallint not null,
  -- Copies of the match's scoring rule. The foreign key below forces them to
  -- equal the match's own values, so the score check can live right here.
  points_to   smallint not null default 11,
  win_by_two  boolean not null default true,
  score_a     smallint not null,
  score_b     smallint not null,

  primary key (match_id, game_number),

  -- ON UPDATE CASCADE: if an officer changes a match's rule, its games follow
  -- (and must still be valid scores). ON DELETE CASCADE: deleting a match
  -- deletes its games.
  constraint match_games_match_rule_fkey
    foreign key (match_id, points_to, win_by_two)
    references public.matches (id, points_to, win_by_two)
    on update cascade on delete cascade,

  constraint match_games_number_valid check (game_number between 1 and 9),
  constraint match_games_scores_range check (
    score_a between 0 and 99 and score_b between 0 and 99
  ),
  -- A finished game. The winner has exactly `points_to` points, and the loser
  -- fewer; with win_by_two the loser has at most points_to - 2. Past the
  -- target (deuce, win_by_two only) the game ends on a 2-point gap, e.g.
  -- 12-10 or 23-21. Walkovers and forfeits are handled in the tournament step.
  constraint match_games_score_valid check (
    (
      greatest(score_a, score_b) = points_to
      and least(score_a, score_b) <= points_to - case when win_by_two then 2 else 1 end
    )
    or (
      win_by_two
      and greatest(score_a, score_b) > points_to
      and abs(score_a - score_b) = 2
    )
  )
);

comment on table public.match_games is
  'One row per game of a match, scored by the match rule (to 11 or 21, win by 2 or not). The match winner is whoever wins more games.';

alter table public.match_games enable row level security;

revoke all on public.match_games from anon, authenticated;
grant select, insert on public.match_games to anon;
grant select, insert, update, delete on public.match_games to authenticated;

create policy "match_games: anyone can read"
  on public.match_games
  for select
  to anon, authenticated
  using (true);

-- Public insert-only, and only for a CASUAL match that was created in the last
-- 2 minutes. That is enough time to submit the games right after the match
-- itself, but nobody can add or change games on an older match.
create policy "match_games: anyone can add games to a fresh casual match"
  on public.match_games
  for insert
  to anon, authenticated
  with check (
    exists (
      select 1
      from public.matches m
      where m.id = match_games.match_id
        and m.match_type = 'casual'
        and m.created_at > now() - interval '2 minutes'
    )
  );

create policy "match_games: officers can add"
  on public.match_games
  for insert
  to authenticated
  with check ((select private.is_officer()));

create policy "match_games: officers can edit"
  on public.match_games
  for update
  to authenticated
  using ((select private.is_officer()))
  with check ((select private.is_officer()));

create policy "match_games: officers can delete"
  on public.match_games
  for delete
  to authenticated
  using ((select private.is_officer()));

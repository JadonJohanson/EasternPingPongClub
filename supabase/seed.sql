-- SAMPLE DATA FOR LOCAL DEVELOPMENT ONLY.
--
-- Loaded automatically on a local `npx supabase start` / `npx supabase db reset`,
-- so the site has players, matches, a finished tournament and events to show
-- while it is being built. All names and emails are made up.
--
-- It is NEVER applied to the hosted projects: `npx supabase db push` does not run
-- this file. Do not paste it into the dashboard SQL editor either.
--
-- The tests empty these tables first, so this file cannot change test results.

insert into public.players (id, display_name) values
  ('a0000000-0000-0000-0000-000000000001', 'Alex Rivera'),
  ('a0000000-0000-0000-0000-000000000002', 'Blake Chen'),
  ('a0000000-0000-0000-0000-000000000003', 'Casey Morgan'),
  ('a0000000-0000-0000-0000-000000000004', 'Dana Patel'),
  ('a0000000-0000-0000-0000-000000000005', 'Eli Johnson'),
  ('a0000000-0000-0000-0000-000000000006', 'Fran Okafor'),
  ('a0000000-0000-0000-0000-000000000007', 'Gus Lindqvist'),
  ('a0000000-0000-0000-0000-000000000008', 'Hana Suzuki');

-- A finished 4-player tournament (3 matches: 2 semifinals and a final).
insert into public.tournaments (id, name, seeding_method, status, held_on) values
  ('b0000000-0000-0000-0000-000000000001', 'Sample Open', 'elo', 'draft', current_date - 14);

insert into public.tournament_entries (tournament_id, player_id, seed, seed_rating, is_new) values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1, 1100, false),
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 2, 1050, false),
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 3, 1000, true),
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000004', 4, 1000, true);

insert into public.matches (id, match_type, tournament_id, player_a_id, player_b_id, played_at) values
  ('c0000000-0000-0000-0000-000000000001', 'tournament', 'b0000000-0000-0000-0000-000000000001',
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000004', now() - interval '14 days'),
  ('c0000000-0000-0000-0000-000000000002', 'tournament', 'b0000000-0000-0000-0000-000000000001',
   'a0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003', now() - interval '14 days'),
  ('c0000000-0000-0000-0000-000000000003', 'tournament', 'b0000000-0000-0000-0000-000000000001',
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', now() - interval '14 days');

insert into public.match_games (match_id, game_number, score_a, score_b) values
  ('c0000000-0000-0000-0000-000000000001', 1, 11, 5),
  ('c0000000-0000-0000-0000-000000000001', 2, 11, 8),
  ('c0000000-0000-0000-0000-000000000002', 1, 11, 9),
  ('c0000000-0000-0000-0000-000000000002', 2, 8, 11),
  ('c0000000-0000-0000-0000-000000000002', 3, 11, 7),
  ('c0000000-0000-0000-0000-000000000003', 1, 11, 6),
  ('c0000000-0000-0000-0000-000000000003', 2, 9, 11),
  ('c0000000-0000-0000-0000-000000000003', 3, 12, 10);

-- Walk the tournament through its life cycle (the rules only allow this order).
update public.tournaments set status = 'in_progress' where id = 'b0000000-0000-0000-0000-000000000001';
update public.tournaments set status = 'complete'    where id = 'b0000000-0000-0000-0000-000000000001';

insert into public.rating_history (player_id, tournament_id, rating_before, rating_after) values
  ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 1100, 1128),
  ('a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 1050, 1056),
  ('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 1000, 986),
  ('a0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 1000, 980);

-- Casual matches (never affect ratings). One uses a typed guest name, one is
-- played to 21 without win-by-2.
insert into public.matches (id, match_type, player_a_id, player_b_id, guest_b_name, points_to, win_by_two, played_at) values
  ('c0000000-0000-0000-0000-000000000011', 'casual', 'a0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000006', null, 11, true, now() - interval '3 days'),
  ('c0000000-0000-0000-0000-000000000012', 'casual', 'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000005', null, 11, true, now() - interval '2 days'),
  ('c0000000-0000-0000-0000-000000000013', 'casual', 'a0000000-0000-0000-0000-000000000007', null, 'Visiting Friend', 11, true, now() - interval '1 day'),
  ('c0000000-0000-0000-0000-000000000014', 'casual', 'a0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000006', null, 21, false, now() - interval '5 hours');

insert into public.match_games (match_id, points_to, win_by_two, game_number, score_a, score_b) values
  ('c0000000-0000-0000-0000-000000000011', 11, true, 1, 11, 4),
  ('c0000000-0000-0000-0000-000000000011', 11, true, 2, 11, 9),
  ('c0000000-0000-0000-0000-000000000012', 11, true, 1, 7, 11),
  ('c0000000-0000-0000-0000-000000000012', 11, true, 2, 11, 8),
  ('c0000000-0000-0000-0000-000000000012', 11, true, 3, 9, 11),
  ('c0000000-0000-0000-0000-000000000013', 11, true, 1, 11, 2),
  ('c0000000-0000-0000-0000-000000000013', 11, true, 2, 11, 6),
  ('c0000000-0000-0000-0000-000000000014', 21, false, 1, 21, 18),
  ('c0000000-0000-0000-0000-000000000014', 21, false, 2, 19, 21),
  ('c0000000-0000-0000-0000-000000000014', 21, false, 3, 21, 20);

-- Events: dates are relative to when the database is created, so there is
-- always an "upcoming" one. 'practice' and 'tournament' show different kinds.
insert into public.events (title, description, location, starts_at, ends_at, kind) values
  ('Weekly practice', 'Open play, all levels welcome. Paddles provided.', 'Student Center, Game Room',
   date_trunc('day', now() at time zone 'America/New_York') + interval '2 days 19 hours', date_trunc('day', now() at time zone 'America/New_York') + interval '2 days 21 hours', 'practice'),
  ('Fall Open Tournament', 'Single elimination, seeded by club rating.', 'Student Center, Ballroom',
   date_trunc('day', now() at time zone 'America/New_York') + interval '9 days 18 hours', date_trunc('day', now() at time zone 'America/New_York') + interval '9 days 22 hours', 'tournament'),
  ('Pizza and ping pong', 'Casual social night.', 'Student Center, Game Room',
   date_trunc('day', now() at time zone 'America/New_York') + interval '16 days 19 hours', null, 'social');

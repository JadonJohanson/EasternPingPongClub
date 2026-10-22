-- Who can do what with matches and match_games.
-- Same style as 001: anon (not logged in), member (logged in, not an officer),
-- officer, then rules the database enforces for everybody.
-- (See the top of 001_foundation_access.test.sql for how role switching and the
-- error codes work. New code here: 23503 = a foreign key points at nothing.)
--
-- Reminder: the website adds a match and its games in SEPARATE requests, so
-- the tests do the same, one statement at a time.

begin;
select plan(60);

-- ---------------------------------------------------------------------------
-- Test data (created as the setup role, so RLS does not apply)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'officer-one@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'member@example.test');

insert into public.officers (user_id) values
  ('11111111-1111-1111-1111-111111111111');

insert into public.players (id, display_name) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Alice Test'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bob Test');

-- A tournament that both players have entered (tournament matches must refer
-- to a real tournament and to players entered in it).
insert into public.tournaments (id, name) values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Test Open');
insert into public.tournament_entries (tournament_id, player_id) values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

-- An OLD casual match (created an hour ago) with one game, and a tournament match.
insert into public.matches (id, match_type, player_a_id, player_b_id, played_at, created_at) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'casual',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   now() - interval '1 hour', now() - interval '1 hour');
insert into public.matches (id, match_type, tournament_id, player_a_id, player_b_id) values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'tournament', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
insert into public.match_games (match_id, game_number, score_a, score_b) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 1, 11, 7);

-- ---------------------------------------------------------------------------
-- anon: a visitor who is not logged in
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"role": "anon"}';
set local role anon;

select is((select count(*) from public.matches), 2::bigint, 'anon can read matches');
select is((select count(*) from public.match_games), 1::bigint, 'anon can read match games');

select lives_ok($$ insert into public.matches (match_type, player_a_id, guest_b_name)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Guest Gary') $$,
  'anon can log a casual match against a guest');
select lives_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  select id, 1, 11, 7 from public.matches where guest_b_name = 'Guest Gary' $$,
  'anon can add a game to a match created seconds ago');
select lives_ok($$ insert into public.matches (match_type, player_a_id, player_b_id)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  'anon can log a casual match between two players');

select lives_ok($$ insert into public.matches (match_type, player_a_id, guest_b_name, points_to, win_by_two)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Guest Gina', 21, false) $$,
  'anon can choose the scoring rule (to 21, no win-by-2) for a casual match');

select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id)
  values ('tournament', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '42501', null, 'anon cannot log a tournament match (RLS)');
select throws_ok($$ insert into public.matches (match_type, tournament_id, player_a_id, player_b_id)
  values ('casual', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '42501', null, 'anon cannot set tournament_id (no column permission)');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id, created_at)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', now() + interval '1 day') $$,
  '42501', null, 'anon cannot set created_at');
select throws_ok($$ insert into public.matches (id, match_type, player_a_id, player_b_id)
  values (gen_random_uuid(), 'casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '42501', null, 'anon cannot choose the match id');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id, played_at)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', now() - interval '40 days') $$,
  '42501', null, 'anon cannot log a match played more than 30 days ago');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id, played_at)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', now() + interval '1 day') $$,
  '42501', null, 'anon cannot log a match played in the future');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  '23514', null, 'anon cannot log a player playing themselves');

select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 2, 11, 5) $$,
  '42501', null, 'anon cannot add a game to an older casual match');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 1, 11, 5) $$,
  '42501', null, 'anon cannot add a game to a tournament match');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  select id, 2, 11, 10 from public.matches where guest_b_name = 'Guest Gary' $$,
  '23514', null, 'a game of 11-10 is rejected (must win by 2)');

select throws_ok($$ update public.matches set guest_b_name = 'Hacked' $$,
  '42501', null, 'anon cannot edit matches');
select throws_ok($$ delete from public.matches $$,
  '42501', null, 'anon cannot delete matches');
select throws_ok($$ update public.match_games set score_a = 0 $$,
  '42501', null, 'anon cannot edit games');
select throws_ok($$ delete from public.match_games $$,
  '42501', null, 'anon cannot delete games');

-- ---------------------------------------------------------------------------
-- member: logged in, but NOT an officer
-- ---------------------------------------------------------------------------
reset role;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
set local role authenticated;

select lives_ok($$ insert into public.matches (match_type, player_a_id, guest_b_name)
  values ('casual', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Guest Greta') $$,
  'a non-officer can log a casual match');
select throws_ok($$ insert into public.matches (match_type, tournament_id, player_a_id, player_b_id)
  values ('tournament', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '42501', null, 'a non-officer cannot log a tournament match (RLS)');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id, created_at)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', now() + interval '1 day') $$,
  '42501', null, 'a non-officer cannot fake created_at to keep the games window open');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 2, 11, 5) $$,
  '42501', null, 'a non-officer cannot add a game to an older match');

-- Run without error but RLS filters them down to zero rows:
update public.matches set guest_b_name = 'Hacked';
delete from public.matches;
update public.match_games set score_a = 0;
delete from public.match_games;

reset role;
select is((select count(*) from public.matches where guest_b_name = 'Hacked'), 0::bigint,
  'a non-officer could not edit matches');
select is((select count(*) from public.matches), 6::bigint,
  'a non-officer could not delete matches');
select is((select score_a from public.match_games where match_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  11::smallint, 'a non-officer could not edit or delete games');

-- ---------------------------------------------------------------------------
-- officer
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
set local role authenticated;

select lives_ok($$ insert into public.matches (id, match_type, tournament_id, player_a_id, player_b_id)
  values ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'tournament', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  'an officer can add a tournament match');
select lives_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('ffffffff-ffff-ffff-ffff-ffffffffffff', 1, 12, 10) $$,
  'an officer can add a game (12-10 is valid)');
select lives_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 2, 9, 11) $$,
  'an officer can add a game to an older casual match');
select lives_ok($$ update public.match_games set score_a = 11, score_b = 9
  where match_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and game_number = 2 $$,
  'an officer can correct a game score');
select lives_ok($$ update public.matches set played_at = now() - interval '2 hours'
  where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff' $$,
  'an officer can edit a match');
select lives_ok($$ delete from public.matches where id = 'ffffffff-ffff-ffff-ffff-ffffffffffff' $$,
  'an officer can delete a match');

reset role;
select is((select score_b from public.match_games
  where match_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and game_number = 2),
  9::smallint, 'the officer game correction was saved');
select is((select count(*) from public.match_games where match_id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'),
  0::bigint, 'deleting a match also deleted its games');

-- ---------------------------------------------------------------------------
-- Database constraints (these apply to everyone, including the setup role)
-- ---------------------------------------------------------------------------
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id)
  values ('tournament', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '23514', null, 'a tournament match must have a tournament_id');
select throws_ok($$ insert into public.matches (match_type, tournament_id, player_a_id, player_b_id)
  values ('casual', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '23514', null, 'a casual match cannot have a tournament_id');
select throws_ok($$ insert into public.matches (match_type, tournament_id, player_a_id, guest_b_name)
  values ('tournament', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Guest Gary') $$,
  '23514', null, 'a tournament match cannot have a guest');
select throws_ok($$ insert into public.matches (match_type, guest_a_name, guest_b_name)
  values ('casual', 'Guest One', 'Guest Two') $$,
  '23514', null, 'a match needs at least one club player');
select throws_ok($$ insert into public.matches (match_type, player_a_id, guest_a_name, player_b_id)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Guest Gary', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '23514', null, 'a side cannot be both a player and a guest');
select throws_ok($$ insert into public.matches (match_type, player_a_id)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  '23514', null, 'a match needs two sides');
select throws_ok($$ insert into public.matches (match_type, player_a_id, guest_b_name)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '  ') $$,
  '23514', null, 'a blank guest name is rejected');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '99999999-9999-9999-9999-999999999999') $$,
  '23503', null, 'a match must refer to players that exist');
select throws_ok($$ delete from public.players where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  '23503', null, 'a player with matches cannot be deleted');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id)
  values ('friendly', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '23514', null, 'match_type must be casual or tournament');

select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 1, 11, 3) $$,
  '23505', null, 'a match cannot have two game 1s');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 10, 11, 3) $$,
  '23514', null, 'game numbers go from 1 to 9');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 3, 12, 11) $$,
  '23514', null, 'a game of 12-11 is rejected');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 3, 10, 8) $$,
  '23514', null, 'a game that stops before 11 is rejected');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 3, 11, 10) $$,
  '23514', null, 'a game of 11-10 is rejected');
select lives_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 3, 14, 12) $$,
  'a long deuce game like 14-12 is accepted');

-- Scoring rules: games to 11 or 21, with or without win-by-2.
insert into public.matches (id, match_type, player_a_id, player_b_id, points_to, win_by_two) values
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'casual',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 21, true),
  ('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 'casual',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 11, false);

select lives_ok($$ insert into public.match_games (match_id, game_number, points_to, win_by_two, score_a, score_b)
  values ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 1, 21, true, 21, 15) $$,
  'a game of 21-15 is accepted in a match to 21');
select throws_ok($$ insert into public.match_games (match_id, game_number, points_to, win_by_two, score_a, score_b)
  values ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 2, 21, true, 21, 20) $$,
  '23514', null, 'a game of 21-20 is rejected when win-by-2 applies');
select lives_ok($$ insert into public.match_games (match_id, game_number, points_to, win_by_two, score_a, score_b)
  values ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 2, 21, true, 21, 23) $$,
  'a deuce game of 21-23 is accepted in a match to 21');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 3, 11, 3) $$,
  '23503', null, 'a game must use the same scoring rule as its match');
select lives_ok($$ insert into public.match_games (match_id, game_number, points_to, win_by_two, score_a, score_b)
  values ('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 1, 11, false, 11, 10) $$,
  'a game of 11-10 is accepted when win-by-2 is off');
select throws_ok($$ insert into public.match_games (match_id, game_number, points_to, win_by_two, score_a, score_b)
  values ('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 2, 11, false, 12, 10) $$,
  '23514', null, 'a game of 12-10 is rejected when win-by-2 is off (first to 11 wins)');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id, points_to)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 15) $$,
  '23514', null, 'games can only be to 11 or 21 (15 is rejected)');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id, points_to)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 6) $$,
  '23514', null, 'games to 6 are not allowed');
select throws_ok($$ update public.matches set points_to = 11 where id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1' $$,
  '23514', null, 'changing a match rule is refused when its existing games would become invalid');

select * from finish();
rollback;

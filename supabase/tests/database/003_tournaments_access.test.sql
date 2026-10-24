-- Who can do what with tournaments, tournament_entries and rating_history, plus
-- the tournament life cycle (draft -> in_progress -> complete), seeding lock,
-- walkovers and the lock on a completed tournament.
-- Roles and error codes work as in 001 and 002. New code here:
-- 55000 = our own trigger refused the change (wrong state for this action).

begin;
select plan(60);

-- ---------------------------------------------------------------------------
-- Test data (setup role)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'officer-one@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'member@example.test');
insert into public.officers (user_id) values ('11111111-1111-1111-1111-111111111111');

insert into public.players (id, display_name) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Alice Test'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bob Test'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Cara Test'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Dan Test');

insert into public.tournaments (id, name) values
  ('11110000-0000-0000-0000-000000000001', 'Existing Draft');
insert into public.tournament_entries (tournament_id, player_id, seed, seed_rating) values
  ('11110000-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 1, 1000);
insert into public.rating_history (player_id, tournament_id, rating_before, rating_after) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11110000-0000-0000-0000-000000000001', 1000, 1016);

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"role": "anon"}';
set local role anon;

select is((select count(*) from public.tournaments), 1::bigint, 'anon can read tournaments');
select is((select count(*) from public.tournament_entries), 1::bigint, 'anon can read tournament entries');
select is((select count(*) from public.rating_history), 1::bigint, 'anon can read rating history');
select throws_ok($$ insert into public.tournaments (name) values ('Fake') $$,
  '42501', null, 'anon cannot create a tournament');
select throws_ok($$ update public.tournaments set name = 'Hacked' $$,
  '42501', null, 'anon cannot edit a tournament');
select throws_ok($$ delete from public.tournaments $$,
  '42501', null, 'anon cannot delete a tournament');
select throws_ok($$ insert into public.tournament_entries (tournament_id, player_id)
  values ('11110000-0000-0000-0000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '42501', null, 'anon cannot add a tournament entry');
select throws_ok($$ insert into public.rating_history (player_id, tournament_id, rating_before, rating_after)
  values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11110000-0000-0000-0000-000000000001', 1000, 1000) $$,
  '42501', null, 'anon cannot write rating history');

-- ---------------------------------------------------------------------------
-- member (logged in, not an officer)
-- ---------------------------------------------------------------------------
reset role;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
set local role authenticated;

select throws_ok($$ insert into public.tournaments (name) values ('Fake') $$,
  '42501', null, 'a non-officer cannot create a tournament (RLS)');
select throws_ok($$ insert into public.tournament_entries (tournament_id, player_id)
  values ('11110000-0000-0000-0000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '42501', null, 'a non-officer cannot add a tournament entry (RLS)');
select throws_ok($$ insert into public.rating_history (player_id, tournament_id, rating_before, rating_after)
  values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11110000-0000-0000-0000-000000000001', 1000, 1000) $$,
  '42501', null, 'a non-officer cannot write rating history (RLS)');

-- Filtered to zero rows by RLS, no error:
update public.tournaments set name = 'Hacked';
delete from public.tournaments;
update public.tournament_entries set seed = 9;
delete from public.tournament_entries;
delete from public.rating_history;

reset role;
select is((select name from public.tournaments), 'Existing Draft',
  'a non-officer could not edit or delete a tournament');
select is((select seed from public.tournament_entries), 1::smallint,
  'a non-officer could not edit or delete an entry');
select is((select count(*) from public.rating_history), 1::bigint,
  'a non-officer could not delete rating history');

-- ---------------------------------------------------------------------------
-- officer: run a whole tournament
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
set local role authenticated;

select lives_ok($$ insert into public.tournaments (id, name, seeding_method, third_place_match)
  values ('22220000-0000-0000-0000-000000000002', 'Fall Open', 'random', true) $$,
  'an officer can create a tournament');
select lives_ok($$ insert into public.tournament_entries (tournament_id, player_id) values
  ('22220000-0000-0000-0000-000000000002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('22220000-0000-0000-0000-000000000002', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  ('22220000-0000-0000-0000-000000000002', 'cccccccc-cccc-cccc-cccc-cccccccccccc') $$,
  'an officer can add players to a draft tournament');
select lives_ok($$ update public.tournament_entries set seed = case player_id
    when 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' then 1
    when 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' then 2
    else 3 end,
  seed_rating = 1000, random_order = 5
  where tournament_id = '22220000-0000-0000-0000-000000000002' $$,
  'an officer can set seeds and the rating snapshot in a draft');
select lives_ok($$ update public.tournament_entries set seed = 3 - seed
  where tournament_id = '22220000-0000-0000-0000-000000000002' and seed in (1, 2) $$,
  'two players can swap seeds in one update (drag-to-swap)');
select throws_ok($$ update public.tournament_entries set seed = 1
  where tournament_id = '22220000-0000-0000-0000-000000000002' and seed = 3 $$,
  '23505', null, 'two players cannot share a seed');
select throws_ok($$ update public.tournaments set status = 'complete'
  where id = '22220000-0000-0000-0000-000000000002' $$,
  '55000', null, 'a draft cannot jump straight to complete');
select lives_ok($$ update public.tournaments set status = 'in_progress'
  where id = '22220000-0000-0000-0000-000000000002' $$,
  'an officer can start a tournament');

select throws_ok($$ update public.tournament_entries set seed = 3, seed_rating = 1
  where tournament_id = '22220000-0000-0000-0000-000000000002' and seed = 2 $$,
  '55000', null, 'seeding is locked once the tournament has started');
select throws_ok($$ insert into public.tournament_entries (tournament_id, player_id)
  values ('22220000-0000-0000-0000-000000000002', 'dddddddd-dddd-dddd-dddd-dddddddddddd') $$,
  '42501', null, 'players cannot be added after the tournament has started');
select throws_ok($$ update public.tournaments set format = 'double_elimination'
  where id = '22220000-0000-0000-0000-000000000002' $$,
  '55000', null, 'tournament setup is locked once started');
select throws_ok($$ update public.tournaments set status = 'draft'
  where id = '22220000-0000-0000-0000-000000000002' $$,
  '55000', null, 'a started tournament cannot go back to draft');
delete from public.tournament_entries where tournament_id = '22220000-0000-0000-0000-000000000002';
delete from public.tournaments where id = '22220000-0000-0000-0000-000000000002';

reset role;
select is((select count(*) from public.tournament_entries where tournament_id = '22220000-0000-0000-0000-000000000002'),
  3::bigint, 'entries cannot be deleted after the tournament has started');
select is((select count(*) from public.tournaments where id = '22220000-0000-0000-0000-000000000002'),
  1::bigint, 'a started tournament cannot be deleted');

set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
set local role authenticated;

select lives_ok($$ update public.tournament_entries set status = 'withdrawn', final_place = 3
  where tournament_id = '22220000-0000-0000-0000-000000000002' and player_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' $$,
  'an officer can record a withdrawal after the start');

-- matches inside the tournament
select lives_ok($$ insert into public.matches (id, match_type, tournament_id, player_a_id, player_b_id)
  values ('aaaa0000-0000-0000-0000-00000000000a', 'tournament', '22220000-0000-0000-0000-000000000002',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  'an officer can add a tournament match between entered players');
select throws_ok($$ insert into public.matches (match_type, tournament_id, player_a_id, player_b_id)
  values ('tournament', '22220000-0000-0000-0000-000000000002',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'dddddddd-dddd-dddd-dddd-dddddddddddd') $$,
  '23503', null, 'a tournament match needs players who entered that tournament');
select throws_ok($$ insert into public.matches (match_type, tournament_id, player_a_id, player_b_id)
  values ('tournament', '99990000-0000-0000-0000-000000000009',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '42501', null, 'an officer cannot add a tournament match for a tournament that does not exist');
select lives_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('aaaa0000-0000-0000-0000-00000000000a', 1, 11, 4) $$,
  'an officer can add a game to a tournament match');

-- walkovers
select lives_ok($$ insert into public.matches (id, match_type, tournament_id, player_a_id, player_b_id, is_walkover, walkover_winner)
  values ('bbbb0000-0000-0000-0000-00000000000b', 'tournament', '22220000-0000-0000-0000-000000000002',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true, 'a') $$,
  'an officer can record a walkover (no games)');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('bbbb0000-0000-0000-0000-00000000000b', 1, 11, 4) $$,
  '55000', null, 'a walkover cannot have games');
select throws_ok($$ update public.matches set is_walkover = true, walkover_winner = 'a'
  where id = 'aaaa0000-0000-0000-0000-00000000000a' $$,
  '55000', null, 'a match with games cannot become a walkover');
select throws_ok($$ insert into public.matches (match_type, tournament_id, player_a_id, player_b_id, is_walkover)
  values ('tournament', '22220000-0000-0000-0000-000000000002',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true) $$,
  '23514', null, 'a walkover must say who won');
select throws_ok($$ insert into public.matches (match_type, tournament_id, player_a_id, player_b_id, walkover_winner)
  values ('tournament', '22220000-0000-0000-0000-000000000002',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'a') $$,
  '23514', null, 'a normal match cannot name a walkover winner');
select throws_ok($$ insert into public.matches (match_type, player_a_id, player_b_id, is_walkover, walkover_winner)
  values ('casual', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, 'a') $$,
  '23514', null, 'a casual match cannot be a walkover');

-- finishing and locking
select lives_ok($$ update public.tournaments set status = 'complete'
  where id = '22220000-0000-0000-0000-000000000002' $$,
  'an officer can complete a tournament');

reset role;
select isnt((select completed_at from public.tournaments where id = '22220000-0000-0000-0000-000000000002'),
  null::timestamptz, 'completing a tournament sets completed_at');

set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
set local role authenticated;

select throws_ok($$ insert into public.matches (match_type, tournament_id, player_a_id, player_b_id)
  values ('tournament', '22220000-0000-0000-0000-000000000002',
          'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc') $$,
  '42501', null, 'a completed tournament is locked: no new matches');
select throws_ok($$ insert into public.match_games (match_id, game_number, score_a, score_b)
  values ('aaaa0000-0000-0000-0000-00000000000a', 2, 11, 4) $$,
  '42501', null, 'a completed tournament is locked: no new games');
update public.match_games set score_a = 0 where match_id = 'aaaa0000-0000-0000-0000-00000000000a';
update public.matches set played_at = now() - interval '9 days' where id = 'aaaa0000-0000-0000-0000-00000000000a';
delete from public.matches where id = 'bbbb0000-0000-0000-0000-00000000000b';
update public.tournament_entries set final_place = 1
  where tournament_id = '22220000-0000-0000-0000-000000000002' and player_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

reset role;
select is((select score_a from public.match_games where match_id = 'aaaa0000-0000-0000-0000-00000000000a'),
  11::smallint, 'a completed tournament is locked: games cannot be edited');
select is((select count(*) from public.matches where id = 'bbbb0000-0000-0000-0000-00000000000b'),
  1::bigint, 'a completed tournament is locked: matches cannot be deleted');
select is((select final_place from public.tournament_entries
  where tournament_id = '22220000-0000-0000-0000-000000000002' and player_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  null::smallint, 'a completed tournament is locked: entries cannot be edited');

set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
set local role authenticated;

select lives_ok($$ update public.tournaments set status = 'in_progress'
  where id = '22220000-0000-0000-0000-000000000002' $$,
  'an officer can reopen a completed tournament to fix a result');
select lives_ok($$ update public.match_games set score_a = 11, score_b = 9
  where match_id = 'aaaa0000-0000-0000-0000-00000000000a' $$,
  'after reopening, a game can be corrected');

-- rating history and draft deletion
select lives_ok($$ insert into public.rating_history (player_id, tournament_id, rating_before, rating_after)
  values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22220000-0000-0000-0000-000000000002', 1000, 984) $$,
  'an officer can write rating history');
select throws_ok($$ insert into public.rating_history (player_id, tournament_id, rating_before, rating_after)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22220000-0000-0000-0000-000000000002', 1000, -5) $$,
  '23514', null, 'a negative rating is rejected');
select lives_ok($$ delete from public.tournaments where id = '11110000-0000-0000-0000-000000000001' $$,
  'an officer can delete a draft tournament');

reset role;
select is((select count(*) from public.tournament_entries where tournament_id = '11110000-0000-0000-0000-000000000001'),
  0::bigint, 'deleting a draft also deleted its entries');

-- ---------------------------------------------------------------------------
-- Database constraints (apply to everyone, including the setup role)
-- ---------------------------------------------------------------------------
select throws_ok($$ insert into public.tournaments (name, status) values ('X', 'in_progress') $$,
  '55000', null, 'a new tournament must start as a draft');
select throws_ok($$ insert into public.tournaments (name, format) values ('X', 'round_robin') $$,
  '23514', null, 'format must be single or double elimination');
select throws_ok($$ insert into public.tournaments (name, seeding_method) values ('X', 'alphabetical') $$,
  '23514', null, 'seeding method must be elo or random');
select throws_ok($$ insert into public.tournaments (name, points_to) values ('X', 15) $$,
  '23514', null, 'tournament games are to 11 or 21');
select throws_ok($$ insert into public.tournaments (name) values ('  ') $$,
  '23514', null, 'a blank tournament name is rejected');
select throws_ok($$ insert into public.tournament_entries (tournament_id, player_id, seed)
  values ('22220000-0000-0000-0000-000000000002', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 0) $$,
  '23514', null, 'a seed must be 1 or more');
select throws_ok($$ insert into public.tournament_entries (tournament_id, player_id, status)
  values ('22220000-0000-0000-0000-000000000002', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'maybe') $$,
  '23514', null, 'an entry status must be active or withdrawn');
select throws_ok($$ delete from public.players where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  '23503', null, 'a player in a tournament cannot be deleted');
select throws_ok($$ delete from public.tournaments where id = '22220000-0000-0000-0000-000000000002' $$,
  '23503', null, 'a tournament with matches cannot be deleted');

select * from finish();
rollback;

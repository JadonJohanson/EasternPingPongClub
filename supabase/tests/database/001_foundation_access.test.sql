-- Who can do what with players, officers and settings.
-- Three kinds of visitor are tested: anon (not logged in), a logged-in user who
-- is NOT an officer ("member"), and an officer.
--
-- How the role switching works: `set local role` makes the database treat the
-- following statements as that role, so grants and RLS apply exactly as they do
-- when the website calls the API. Setting `request.jwt.claims` fakes the login
-- token, which is where auth.uid() reads the user id from. `reset role` goes
-- back to the all-powerful test setup role.
--
-- Error codes: 42501 = permission denied (missing grant, or an RLS policy
-- refusing a new row). 23514 = a CHECK constraint failed. 23505 = a unique /
-- primary key rule failed.
-- Note: an UPDATE or DELETE that RLS filters down to zero rows does NOT raise
-- an error, it silently changes nothing. Those tests check the data afterwards.

begin;
select plan(28);

-- ---------------------------------------------------------------------------
-- Test data (created as the setup role, so RLS does not apply)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'officer-one@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'member@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'officer-two@example.test');

insert into public.officers (user_id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('33333333-3333-3333-3333-333333333333');

insert into public.players (id, display_name) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Alice Test');

-- ---------------------------------------------------------------------------
-- anon: a visitor who is not logged in
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"role": "anon"}';
set local role anon;

select is((select count(*) from public.players), 1::bigint,
  'anon can read players');
select throws_ok($$ insert into public.players (display_name) values ('Mallory') $$,
  '42501', null, 'anon cannot add a player');
select throws_ok($$ update public.players set display_name = 'Hacked' $$,
  '42501', null, 'anon cannot edit a player');
select throws_ok($$ delete from public.players $$,
  '42501', null, 'anon cannot delete a player');
select throws_ok($$ select * from public.officers $$,
  '42501', null, 'anon cannot even read the officers table');
select is((select starting_rating from public.settings), 1000,
  'anon can read settings');
select throws_ok($$ update public.settings set k_factor = 99 $$,
  '42501', null, 'anon cannot change settings');

-- ---------------------------------------------------------------------------
-- member: logged in, but NOT an officer
-- ---------------------------------------------------------------------------
reset role;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
set local role authenticated;

select is((select count(*) from public.players), 1::bigint,
  'a non-officer can read players');
select throws_ok($$ insert into public.players (display_name) values ('Mallory') $$,
  '42501', null, 'a non-officer cannot add a player (blocked by RLS)');
select throws_ok($$ insert into public.officers (user_id) values ('22222222-2222-2222-2222-222222222222') $$,
  '42501', null, 'a non-officer cannot make themselves an officer');
select is((select count(*) from public.officers), 0::bigint,
  'a non-officer sees no rows in officers');

-- These run without error but RLS filters them down to zero rows:
update public.players set display_name = 'Hacked';
delete from public.players;
update public.settings set k_factor = 99;

reset role;
select is((select display_name from public.players where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Alice Test', 'a non-officer could not edit or delete a player');
select is((select k_factor from public.settings), 32,
  'a non-officer could not change settings');

-- ---------------------------------------------------------------------------
-- officer
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
set local role authenticated;

select lives_ok($$ insert into public.players (display_name) values ('Bob Test') $$,
  'an officer can add a player');
select lives_ok($$ update public.players set display_name = 'Alice Renamed' where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  'an officer can edit a player');
select lives_ok($$ delete from public.players where display_name = 'Bob Test' $$,
  'an officer can delete a player');
select lives_ok($$ update public.settings set k_factor = 40 $$,
  'an officer can change settings');
select throws_ok($$ insert into public.settings (id) values (false) $$,
  '42501', null, 'an officer cannot add a second settings row');
select throws_ok($$ delete from public.settings $$,
  '42501', null, 'an officer cannot delete the settings row');
select throws_ok($$ insert into public.officers (user_id) values ('22222222-2222-2222-2222-222222222222') $$,
  '42501', null, 'an officer cannot create officers through the API');
select is((select count(*) from public.officers), 1::bigint,
  'an officer sees only their own row in officers (two officers exist)');
select throws_ok($$ update public.players set display_name = '   ' $$,
  '23514', null, 'a blank player name is rejected by the database');

reset role;
select is((select display_name from public.players where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Alice Renamed', 'the officer edit was saved');
select is((select count(*) from public.players where display_name = 'Bob Test'), 0::bigint,
  'the officer delete was saved');
select is((select k_factor from public.settings), 40,
  'the officer settings change was saved');

-- ---------------------------------------------------------------------------
-- Database constraints (these apply to everyone, including the setup role)
-- ---------------------------------------------------------------------------
select throws_ok($$ insert into public.settings (id) values (true) $$,
  '23505', null, 'a second settings row (id = true) is impossible');
select throws_ok($$ insert into public.settings (id) values (false) $$,
  '23514', null, 'a settings row with id = false is impossible');
select throws_ok($$ insert into public.players (display_name) values (' padded ') $$,
  '23514', null, 'player names with leading or trailing spaces are rejected');

select * from finish();
rollback;

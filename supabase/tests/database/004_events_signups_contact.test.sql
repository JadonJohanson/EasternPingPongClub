-- Events, signups and contact messages.
-- Roles and error codes work as in 001-003. The important rule here: visitors
-- can ADD signups and contact messages but can never READ them.

begin;
select plan(47);

-- Start from empty tables (see the note in 001).
truncate public.events, public.signups, public.contact_messages cascade;

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'officer-one@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'member@example.test');
insert into public.officers (user_id) values ('11111111-1111-1111-1111-111111111111');

insert into public.events (id, title, starts_at) values
  ('e0e0e0e0-0000-0000-0000-000000000001', 'Weekly practice', now() + interval '2 days');
insert into public.signups (name, email, eastern_id, skill_level) values
  ('Existing Signup', 'existing@my.easternct.edu', '12345678', 'beginner');
insert into public.contact_messages (name, email, message) values
  ('Existing Sender', 'sender@example.com', 'Hello');

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"role": "anon"}';
set local role anon;

select is((select count(*) from public.events), 1::bigint, 'anon can read events');
select throws_ok($$ insert into public.events (title, starts_at) values ('Fake', now()) $$,
  '42501', null, 'anon cannot add an event');
select throws_ok($$ update public.events set title = 'Hacked' $$,
  '42501', null, 'anon cannot edit an event');
select throws_ok($$ delete from public.events $$,
  '42501', null, 'anon cannot delete an event');

select lives_ok($$ insert into public.signups (name, email, eastern_id, skill_level)
  values ('Pat Player', 'pat@my.easternct.edu', '01234567', 'intermediate') $$,
  'anon can submit the Sign Up form');
select lives_ok($$ insert into public.contact_messages (name, email, message)
  values ('Sam Sender', 'sam@gmail.com', 'When is practice?') $$,
  'anon can send a contact message');
select throws_ok($$ select * from public.signups $$,
  '42501', null, 'anon cannot read signups');
select throws_ok($$ select email from public.signups $$,
  '42501', null, 'anon cannot read signup emails');
select throws_ok($$ select eastern_id from public.signups $$,
  '42501', null, 'anon cannot read Eastern IDs');
select throws_ok($$ select * from public.contact_messages $$,
  '42501', null, 'anon cannot read contact messages');
select throws_ok($$ update public.signups set skill_level = 'master' $$,
  '42501', null, 'anon cannot edit signups');
select throws_ok($$ delete from public.signups $$,
  '42501', null, 'anon cannot delete signups');
select throws_ok($$ delete from public.contact_messages $$,
  '42501', null, 'anon cannot delete contact messages');
select throws_ok($$ insert into public.signups (id, name, email, eastern_id, skill_level)
  values (gen_random_uuid(), 'Pat Two', 'pat2@my.easternct.edu', '01234568', 'beginner') $$,
  '42501', null, 'anon cannot choose a signup id');
select throws_ok($$ insert into public.signups (name, email, eastern_id, skill_level, created_at)
  values ('Pat Two', 'pat2@my.easternct.edu', '01234568', 'beginner', now() - interval '1 year') $$,
  '42501', null, 'anon cannot set a signup time');

-- ---------------------------------------------------------------------------
-- member (logged in, not an officer)
-- ---------------------------------------------------------------------------
reset role;
set local request.jwt.claims to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
set local role authenticated;

select lives_ok($$ insert into public.signups (name, email, eastern_id, skill_level)
  values ('Logged In', 'li@my.easternct.edu', '11112222', 'advanced') $$,
  'a logged-in non-officer can also submit the form');
select is((select count(*) from public.signups), 0::bigint,
  'a non-officer sees no signups (RLS)');
select is((select count(*) from public.contact_messages), 0::bigint,
  'a non-officer sees no contact messages (RLS)');
select throws_ok($$ insert into public.events (title, starts_at) values ('Fake', now()) $$,
  '42501', null, 'a non-officer cannot add an event (RLS)');

update public.signups set skill_level = 'master';
delete from public.signups;
delete from public.contact_messages;
update public.events set title = 'Hacked';
delete from public.events;

reset role;
select is((select count(*) from public.signups where skill_level = 'master'), 0::bigint,
  'a non-officer could not edit signups');
select is((select count(*) from public.signups), 3::bigint,
  'a non-officer could not delete signups');
select is((select count(*) from public.contact_messages), 2::bigint,
  'a non-officer could not delete contact messages');
select is((select title from public.events), 'Weekly practice',
  'a non-officer could not edit or delete events');

-- ---------------------------------------------------------------------------
-- officer
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
set local role authenticated;

select is((select count(*) from public.signups), 3::bigint, 'an officer can read all signups');
select is((select count(*) from public.contact_messages), 2::bigint, 'an officer can read all contact messages');
select lives_ok($$ insert into public.events (title, location, starts_at, ends_at, kind)
  values ('Fall Open', 'Student Center', now() + interval '7 days', now() + interval '7 days 3 hours', 'tournament') $$,
  'an officer can add an event');
select lives_ok($$ update public.events set cancelled = true where title = 'Fall Open' $$,
  'an officer can edit an event');
select lives_ok($$ delete from public.events where title = 'Fall Open' $$,
  'an officer can delete an event');
select lives_ok($$ update public.signups set skill_level = 'master' where name = 'Pat Player' $$,
  'an officer can edit a signup');
select lives_ok($$ delete from public.signups where name = 'Existing Signup' $$,
  'an officer can delete a signup');
select lives_ok($$ delete from public.contact_messages where name = 'Existing Sender' $$,
  'an officer can delete a contact message');

reset role;
select is((select skill_level from public.signups where name = 'Pat Player'), 'master',
  'the officer signup edit was saved');
select is((select count(*) from public.events where title = 'Fall Open'), 0::bigint,
  'the officer event delete was saved');

-- ---------------------------------------------------------------------------
-- Database constraints
-- ---------------------------------------------------------------------------
select lives_ok($$ insert into public.signups (name, email, eastern_id, skill_level) values
  ('S1', 's1@easternct.edu', '00000001', 'beginner'),
  ('S2', 's2@my.easternct.edu', '00000002', 'intermediate'),
  ('S3', 's3@my.easternct.edu', '00000003', 'advanced'),
  ('S4', 's4@my.easternct.edu', '00000004', 'expert'),
  ('S5', 'S5@MY.EASTERNCT.EDU', '00000005', 'master') $$,
  'all five skill levels and both school email styles are accepted');
select throws_ok($$ insert into public.signups (name, email, eastern_id, skill_level)
  values ('X', 'x@gmail.com', '12345678', 'beginner') $$,
  '23514', null, 'a signup needs a school email');
select throws_ok($$ insert into public.signups (name, email, eastern_id, skill_level)
  values ('X', 'x@evil-easternct.edu', '12345678', 'beginner') $$,
  '23514', null, 'a look-alike school domain is rejected');
select throws_ok($$ insert into public.signups (name, email, eastern_id, skill_level)
  values ('X', 'x@my.easternct.edu', '1234567', 'beginner') $$,
  '23514', null, 'an Eastern ID of 7 digits is rejected');
select throws_ok($$ insert into public.signups (name, email, eastern_id, skill_level)
  values ('X', 'x@my.easternct.edu', '123456789', 'beginner') $$,
  '23514', null, 'an Eastern ID of 9 digits is rejected');
select throws_ok($$ insert into public.signups (name, email, eastern_id, skill_level)
  values ('X', 'x@my.easternct.edu', '1234abcd', 'beginner') $$,
  '23514', null, 'an Eastern ID with letters is rejected');
select throws_ok($$ insert into public.signups (name, email, eastern_id, skill_level)
  values ('X', 'x@my.easternct.edu', '12345678', 'pro') $$,
  '23514', null, 'an unknown skill level is rejected');
select throws_ok($$ insert into public.signups (name, email, eastern_id, skill_level)
  values ('  ', 'x@my.easternct.edu', '12345678', 'beginner') $$,
  '23514', null, 'a blank name is rejected');
select throws_ok($$ insert into public.contact_messages (name, email, message)
  values ('X', 'not-an-email', 'Hi') $$,
  '23514', null, 'a contact message needs a valid-looking email');
select throws_ok($$ insert into public.contact_messages (name, email, message)
  values ('X', 'x@example.com', '   ') $$,
  '23514', null, 'an empty contact message is rejected');
select throws_ok($$ insert into public.contact_messages (name, email, message)
  values ('X', 'x@example.com', repeat('a', 2001)) $$,
  '23514', null, 'a contact message over 2000 characters is rejected');
select throws_ok($$ insert into public.events (title, starts_at, ends_at)
  values ('Backwards', now(), now() - interval '1 hour') $$,
  '23514', null, 'an event cannot end before it starts');
select throws_ok($$ insert into public.events (title, starts_at, kind)
  values ('Odd', now(), 'party') $$,
  '23514', null, 'an event kind must be practice, tournament, social or other');
select throws_ok($$ insert into public.events (title, starts_at, tournament_id)
  values ('Linked', now(), '99990000-0000-0000-0000-000000000009') $$,
  '23503', null, 'an event can only link to a tournament that exists');

select * from finish();
rollback;

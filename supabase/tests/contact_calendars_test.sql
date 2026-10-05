-- Agendas de proches : l'agenda qu'un utilisateur tient pour quelqu'un d'autre
-- (repos, anniversaires…). Il est à lui seul : jamais vu d'un groupe, jamais
-- compté comme ses propres créneaux pris, jamais son « dernier agenda ».
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- Fixtures (en postgres) ------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('a7000000-0000-0000-0000-0000000000a7', 'ana@test.local', '{"display_name":"Ana"}'),
  ('b7000000-0000-0000-0000-0000000000b7', 'ben@test.local', '{"display_name":"Ben"}');
insert into public.groups (id, name) values ('70000000-0000-0000-0000-000000000007', 'Potes');
insert into public.group_members (group_id, user_id, role, share_level) values
  ('70000000-0000-0000-0000-000000000007', 'a7000000-0000-0000-0000-0000000000a7', 'owner', 'details'),
  ('70000000-0000-0000-0000-000000000007', 'b7000000-0000-0000-0000-0000000000b7', 'member', 'details');

-- Ana tient l'agenda de Léa ---------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"a7000000-0000-0000-0000-0000000000a7","role":"authenticated"}';

select lives_ok(
  $$insert into public.calendars (name, color, visibility, contact)
    values ('Léa', '#3366FF', 'invisible', true)$$,
  'Ana crée l''agenda de son amie Léa');
select set_config('agora_test.lea',
  (select id::text from public.calendars where contact and name = 'Léa'), true);
select throws_ok(
  $$insert into public.calendars (name, visibility, contact) values ('Max', null, true)$$,
  '23514', null, 'l''agenda d''un proche n''hérite pas du partage : il est invisible');
select throws_ok(
  $$insert into public.calendars (name, visibility, contact) values ('Max', 'busy', true)$$,
  '23514', null, 'l''agenda d''un proche ne rend jamais « occupé »');
select throws_ok(
  $$update public.calendars set visibility = 'busy' where id = current_setting('agora_test.lea')::uuid$$,
  '23514', null, 'on ne rend pas l''agenda d''un proche visible après coup');
select throws_ok(
  $$update public.calendars set contact = false where id = current_setting('agora_test.lea')::uuid$$,
  '42501', null, 'un agenda de proche le reste');

insert into public.events (calendar_id, title, starts_at, ends_at) values
  (current_setting('agora_test.lea')::uuid, 'Repos de Léa', '2026-10-12 08:00+00', '2026-10-12 18:00+00');
insert into public.events (calendar_id, title, starts_at, ends_at)
  select c.id, 'Dentiste', '2026-10-12 10:00+00', '2026-10-12 11:00+00'
  from public.calendars c
  where c.owner_id = 'a7000000-0000-0000-0000-0000000000a7' and not c.contact;

select is(
  (select count(*)::int from public.my_agenda('2026-10-12 00:00+00', '2026-10-13 00:00+00')
   where title = 'Repos de Léa'),
  1, 'le repos de Léa est dans l''agenda d''Ana');
select is(
  (select count(*)::int from public.group_agenda('70000000-0000-0000-0000-000000000007',
     '2026-10-12 00:00+00', '2026-10-13 00:00+00')
   where starts_at = '2026-10-12 08:00+00'),
  0, 'dans son groupe, Ana ne se voit pas occupée par le repos de Léa');
select is(
  (select count(*)::int from public.group_agenda('70000000-0000-0000-0000-000000000007',
     '2026-10-12 00:00+00', '2026-10-13 00:00+00')
   where title = 'Dentiste'),
  1, 'ses propres rdv restent dans l''agenda du groupe');

-- Même « présent » à un rdv de l'agenda de Léa (inséré par la base : l'app
-- ne le permet pas), Ana n'en paraît pas occupée dans son groupe : la branche
-- des réponses « présent » ne retient que les rdv d'un AUTRE groupe.
reset role;
insert into public.event_responses (event_id, user_id, status)
  select e.id, 'a7000000-0000-0000-0000-0000000000a7', 'yes'
  from public.events e where e.title = 'Repos de Léa';
set local role authenticated;
set local request.jwt.claims = '{"sub":"b7000000-0000-0000-0000-0000000000b7","role":"authenticated"}';
select is(
  (select count(*)::int from public.group_agenda('70000000-0000-0000-0000-000000000007',
     '2026-10-12 00:00+00', '2026-10-13 00:00+00')
   where starts_at = '2026-10-12 08:00+00'),
  0, 'une réponse « présent » à un rdv de proche ne rend personne occupé');

-- Ben ne voit rien de l'agenda de Léa -----------------------------------------------------------
set local request.jwt.claims = '{"sub":"b7000000-0000-0000-0000-0000000000b7","role":"authenticated"}';
select is(
  (select count(*)::int from public.group_agenda('70000000-0000-0000-0000-000000000007',
     '2026-10-12 00:00+00', '2026-10-13 00:00+00')
   where starts_at = '2026-10-12 08:00+00'),
  0, 'les membres du groupe ne voient rien de l''agenda d''un proche');
select is(
  (select count(*)::int from public.calendars where contact),
  0, 'un membre ne lit pas l''agenda d''un proche d''un autre');

-- Le dernier agenda d'Ana est le sien, pas celui de Léa -----------------------------------------
set local request.jwt.claims = '{"sub":"a7000000-0000-0000-0000-0000000000a7","role":"authenticated"}';
select throws_ok(
  $$select public.delete_calendar((select c.id from public.calendars c
      where c.owner_id = 'a7000000-0000-0000-0000-0000000000a7' and not c.contact))$$,
  'P0001', 'last_native_calendar', 'l''agenda d''un proche ne compte pas comme le dernier agenda d''Ana');
select lives_ok(
  $$select public.delete_calendar(current_setting('agora_test.lea')::uuid)$$,
  'Ana supprime l''agenda de Léa');

-- Le planning de Léa, importé par lien iCal -----------------------------------------------------
select set_config('agora_test.ics', public.add_ics_calendar(
  'Planning de Léa', 'https://exemple.test/lea.ics', '#22AA88', p_contact => true)::text, true);
select ok(
  (select contact and kind = 'ics' and visibility = 'invisible' from public.calendars
   where id = current_setting('agora_test.ics')::uuid),
  'un agenda de proche importé est invisible, comme les autres');
select set_config('agora_test.mien',
  public.add_ics_calendar('Mon travail', 'https://exemple.test/moi.ics')::text, true);
select ok(
  (select not contact and visibility is null from public.calendars
   where id = current_setting('agora_test.mien')::uuid),
  'sans l''option, un import reste un agenda à soi');

-- Ni anon, ni un agenda de groupe ---------------------------------------------------------------
reset role;
select throws_ok(
  $$insert into public.calendars (group_id, name, visibility, contact)
    values ('70000000-0000-0000-0000-000000000007', 'Léa', 'invisible', true)$$,
  '23514', null, 'un agenda de groupe n''est jamais celui d''un proche');
select ok(
  not has_function_privilege('anon', 'public.add_ics_calendar(text, text, text, boolean)', 'execute'),
  'anon n''importe rien');

select * from finish();
rollback;

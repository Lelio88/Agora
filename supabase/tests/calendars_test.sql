-- Plusieurs agendas par personne : création, réglages, déplacement d'un rdv
-- d'un agenda à l'autre, suppression (jamais le dernier agenda natif),
-- préférences d'affichage.
begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

insert into auth.users (id, email, raw_user_meta_data) values
  ('33330000-0000-0000-0000-000000000003', 'lea@test.local', '{"display_name":"Léa"}'),
  ('44440000-0000-0000-0000-000000000004', 'max@test.local', '{"display_name":"Max"}');

-- L'agenda de Max, illisible pour Léa : son id est pris ici, en postgres.
select set_config('agora_test.max_calendar',
  (select id::text from public.calendars where owner_id = '44440000-0000-0000-0000-000000000004'), true);

-- Rdv de Léa dans son agenda par défaut, posés en postgres pour fixer les
-- ids (créés par elle, comme l'app le fait) : un rdv ponctuel, une série et
-- une de ses occurrences modifiées.
insert into public.events (id, calendar_id, title, starts_at, ends_at, created_by)
select 'e1000000-0000-0000-0000-0000000000d1', c.id, 'Réunion', '2026-10-06 08:00+00', '2026-10-06 09:00+00',
       c.owner_id
from public.calendars c where c.owner_id = '33330000-0000-0000-0000-000000000003';
insert into public.events (id, calendar_id, title, starts_at, ends_at, timezone, rrule, created_by)
select 'e1000000-0000-0000-0000-0000000000d2', c.id, 'Sport', '2026-10-06 16:00+00', '2026-10-06 17:00+00',
       'Europe/Paris', 'FREQ=WEEKLY', c.owner_id
from public.calendars c where c.owner_id = '33330000-0000-0000-0000-000000000003';
insert into public.events (series_id, recurrence_id, calendar_id, title, starts_at, ends_at)
select id, '2026-10-13 16:00+00', calendar_id, 'Sport (décalé)', '2026-10-13 18:00+00', '2026-10-13 19:00+00'
from public.events where id = 'e1000000-0000-0000-0000-0000000000d2';

set local role authenticated;
set local request.jwt.claims = '{"sub":"33330000-0000-0000-0000-000000000003","role":"authenticated"}';

-- Créer et régler ses agendas ------------------------------------------------------------
select lives_ok($$
  insert into public.calendars (name, color, visibility) values ('Travail', '#1E88E5', 'busy')$$,
  'on crée un second agenda, avec sa couleur et son masquage');
select set_config('agora_test.work',
  (select id::text from public.calendars where name = 'Travail'), true);
select is(
  (select owner_id from public.calendars where id = current_setting('agora_test.work')::uuid),
  '33330000-0000-0000-0000-000000000003'::uuid, 'le nouvel agenda appartient à sa créatrice');
select throws_ok($$
  insert into public.calendars (name, visibility) values ('Tout montrer', 'details')$$,
  '23514', null, 'un agenda ne peut que restreindre (jamais « détails »)');
select lives_ok($$
  update public.calendars set name = 'Boulot', color = '#43A047', visibility = 'invisible'
  where id = current_setting('agora_test.work')::uuid$$,
  'on renomme, recolore et masque son agenda');

-- Déplacer un rdv d'un agenda à l'autre --------------------------------------------------------
select lives_ok($$
  update public.events set calendar_id = current_setting('agora_test.work')::uuid
  where id = 'e1000000-0000-0000-0000-0000000000d1'$$,
  'on range un rdv dans un autre de ses agendas');
select is(
  (select calendar_id from public.events where id = 'e1000000-0000-0000-0000-0000000000d1'),
  current_setting('agora_test.work')::uuid, 'le rdv a changé d''agenda');

-- Une série déplacée emmène ses occurrences modifiées.
select lives_ok($$
  update public.events set calendar_id = current_setting('agora_test.work')::uuid
  where id = 'e1000000-0000-0000-0000-0000000000d2'$$,
  'on range une série dans un autre agenda');
select is(
  (select calendar_id from public.events where series_id = 'e1000000-0000-0000-0000-0000000000d2'),
  current_setting('agora_test.work')::uuid, 'ses occurrences modifiées la suivent');
select throws_ok($$
  update public.events set calendar_id = (select id from public.calendars where name = 'Agenda')
  where series_id = 'e1000000-0000-0000-0000-0000000000d2'$$,
  '22023', 'invalid_series', 'une occurrence modifiée ne quitte pas l''agenda de sa série');

-- Préférences d'affichage ----------------------------------------------------------------
select lives_ok($$
  insert into public.calendar_preferences (calendar_id, hidden)
  values (current_setting('agora_test.work')::uuid, true)$$,
  'on masque un de ses agendas dans sa propre vue');
select lives_ok($$
  insert into public.calendar_preferences (calendar_id, hidden)
  values (current_setting('agora_test.work')::uuid, false)
  on conflict (user_id, calendar_id) do update set hidden = excluded.hidden$$,
  'on le réaffiche (même ligne)');
select is(
  (select hidden from public.calendar_preferences where calendar_id = current_setting('agora_test.work')::uuid),
  false, 'la préférence est à jour');

-- Max ne touche à rien de Léa ----------------------------------------------------------------
set local request.jwt.claims = '{"sub":"44440000-0000-0000-0000-000000000004","role":"authenticated"}';
select is((select count(*)::int from public.calendar_preferences), 0,
  'Max ne voit pas les préférences de Léa');
select throws_ok($$
  insert into public.calendar_preferences (calendar_id, hidden)
  values (current_setting('agora_test.work')::uuid, true)$$,
  '42501', null, 'pas de préférence sur un agenda qu''on ne lit pas');
-- Sans droit, la RLS masque les lignes : ces écritures ne touchent rien.
update public.calendars set name = 'Piraté' where id = current_setting('agora_test.work')::uuid;
update public.events set calendar_id = current_setting('agora_test.max_calendar')::uuid
where id = 'e1000000-0000-0000-0000-0000000000d1';
select throws_ok($$select public.delete_calendar(current_setting('agora_test.work')::uuid)$$,
  'P0002', 'calendar_not_found', 'Max ne supprime pas l''agenda de Léa');

set local request.jwt.claims = '{"sub":"33330000-0000-0000-0000-000000000003","role":"authenticated"}';
select is(
  (select name from public.calendars where id = current_setting('agora_test.work')::uuid),
  'Boulot', 'Max n''a pas renommé l''agenda de Léa');
select is(
  (select calendar_id from public.events where id = 'e1000000-0000-0000-0000-0000000000d1'),
  current_setting('agora_test.work')::uuid, 'Max n''a pas déplacé le rdv de Léa');
select throws_ok($$
  update public.events set calendar_id = current_setting('agora_test.max_calendar')::uuid
  where id = 'e1000000-0000-0000-0000-0000000000d1'$$,
  '42501', null, 'Léa ne range pas un rdv dans l''agenda de Max');

-- Agenda de groupe : seul le créateur d'un rdv le change d'agenda ------------------------------
-- Max est admin du groupe, Léa simple membre ; Léa y a posé un rdv.
reset role;
insert into public.groups (id, name) values ('9a000000-0000-0000-0000-00000000009a', 'Club');
insert into public.group_members (group_id, user_id, role) values
  ('9a000000-0000-0000-0000-00000000009a', '44440000-0000-0000-0000-000000000004', 'admin'),
  ('9a000000-0000-0000-0000-00000000009a', '33330000-0000-0000-0000-000000000003', 'member');
insert into public.calendars (id, owner_id, group_id, name)
values ('cb000000-0000-0000-0000-0000000000cb', null, '9a000000-0000-0000-0000-00000000009a', 'Club');
insert into public.events (id, calendar_id, title, starts_at, ends_at, created_by)
values ('e1000000-0000-0000-0000-0000000000d3', 'cb000000-0000-0000-0000-0000000000cb', 'Sortie',
        '2026-10-10 08:00+00', '2026-10-10 12:00+00', '33330000-0000-0000-0000-000000000003');

set local role authenticated;
set local request.jwt.claims = '{"sub":"44440000-0000-0000-0000-000000000004","role":"authenticated"}';
select throws_ok($$
  update public.events set calendar_id = current_setting('agora_test.max_calendar')::uuid
  where id = 'e1000000-0000-0000-0000-0000000000d3'$$,
  'P0002', 'event_not_found',
  'un admin ne sort pas le rdv d''un membre du groupe vers son agenda personnel');
select lives_ok($$
  update public.events set title = 'Sortie (modifiée)' where id = 'e1000000-0000-0000-0000-0000000000d3'$$,
  'l''admin garde le droit de modifier le rdv dans le groupe');

set local request.jwt.claims = '{"sub":"33330000-0000-0000-0000-000000000003","role":"authenticated"}';
select is(
  (select calendar_id from public.events where id = 'e1000000-0000-0000-0000-0000000000d3'),
  'cb000000-0000-0000-0000-0000000000cb'::uuid, 'le rdv de Léa reste dans l''agenda du groupe');

-- Suppression ----------------------------------------------------------------------------
select throws_ok($$delete from public.calendars where id = current_setting('agora_test.work')::uuid$$,
  '42501', null, 'on ne supprime un agenda que par delete_calendar');
select lives_ok($$select public.delete_calendar(current_setting('agora_test.work')::uuid)$$,
  'Léa supprime son agenda Boulot');
select is(
  (select count(*)::int from public.events
   where id in ('e1000000-0000-0000-0000-0000000000d1', 'e1000000-0000-0000-0000-0000000000d2')
      or series_id = 'e1000000-0000-0000-0000-0000000000d2'),
  0, 'ses rdv, séries et occurrences modifiées disparaissent avec lui');
select is((select count(*)::int from public.calendar_preferences), 0,
  'sa préférence d''affichage aussi');
select throws_ok(
  $$select public.delete_calendar((select id from public.calendars where name = 'Agenda'))$$,
  'P0001', 'last_native_calendar', 'le dernier agenda natif ne se supprime pas');
select is(
  (select count(*)::int from public.calendars where owner_id = '33330000-0000-0000-0000-000000000003'),
  1, 'Léa garde son agenda par défaut');

select * from finish();
rollback;

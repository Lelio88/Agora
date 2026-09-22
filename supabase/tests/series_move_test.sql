-- Modifier « toute la série » depuis une de ses occurrences : la série se
-- décale d'autant (jours et heure locale dans son fuseau), sans jamais
-- reprendre les dates de l'occurrence touchée comme nouveau début.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, email, raw_user_meta_data) values
  ('55550000-0000-0000-0000-000000000005', 'ines@test.local', '{"display_name":"Inès"}'),
  ('66660000-0000-0000-0000-000000000006', 'paul@test.local', '{"display_name":"Paul"}');

-- Série d'Inès : le mardi à 18 h à Paris depuis le 6 octobre (heure d'été),
-- une occurrence supprimée (13/10) et une déplacée (20/10). Une série « journée
-- entière » et un rdv ponctuel à côté.
insert into public.events (id, calendar_id, title, starts_at, ends_at, timezone, rrule, exdates)
select 'e2000000-0000-0000-0000-0000000000e1', c.id, 'Yoga',
       '2026-10-06 16:00+00', '2026-10-06 17:00+00', 'Europe/Paris', 'FREQ=WEEKLY;BYDAY=TU',
       array['2026-10-13 16:00+00'::timestamptz]
from public.calendars c where c.owner_id = '55550000-0000-0000-0000-000000000005';
insert into public.events (series_id, recurrence_id, calendar_id, title, starts_at, ends_at)
select id, '2026-10-20 16:00+00', calendar_id, 'Yoga (décalé)', '2026-10-20 18:00+00', '2026-10-20 19:00+00'
from public.events where id = 'e2000000-0000-0000-0000-0000000000e1';
insert into public.events (id, calendar_id, title, starts_at, ends_at, all_day, timezone, rrule)
select 'e2000000-0000-0000-0000-0000000000e2', c.id, 'Garde',
       '2026-10-06 00:00+00', '2026-10-07 00:00+00', true, 'Europe/Paris', 'FREQ=WEEKLY'
from public.calendars c where c.owner_id = '55550000-0000-0000-0000-000000000005';
insert into public.events (id, calendar_id, title, starts_at, ends_at)
select 'e2000000-0000-0000-0000-0000000000e3', c.id, 'Dentiste', '2026-10-08 08:00+00', '2026-10-08 09:00+00'
from public.calendars c where c.owner_id = '55550000-0000-0000-0000-000000000005';
select set_config('agora_test.calendar',
  (select id::text from public.calendars where owner_id = '55550000-0000-0000-0000-000000000005'), true);

set local role authenticated;
set local request.jwt.claims = '{"sub":"55550000-0000-0000-0000-000000000005","role":"authenticated"}';

select is(
  (select rrule from public.my_agenda('2026-10-15', '2026-10-25') where title = 'Yoga (décalé)'),
  'FREQ=WEEKLY;BYDAY=TU',
  'une occurrence modifiée porte la règle de sa série (l''app en bâtit ses brouillons)');

-- Renommer depuis une occurrence d'hiver (1er décembre, 18 h = 17 h UTC) -------------------------
select lives_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e1', '2026-12-01 17:00+00',
    current_setting('agora_test.calendar')::uuid, 'Yoga doux', null, null,
    '2026-12-01 17:00+00', '2026-12-01 18:00+00', false, 'FREQ=WEEKLY;BYDAY=TU', null, false)$$,
  'on renomme toute la série depuis une occurrence de décembre');
select ok(
  (select starts_at = '2026-10-06 16:00+00' and ends_at = '2026-10-06 17:00+00'
   from public.events where id = 'e2000000-0000-0000-0000-0000000000e1'),
  'la série commence toujours le 6 octobre : elle ne saute pas à l''occurrence touchée');
select ok(
  (select cardinality(exdates) = 1 from public.events where id = 'e2000000-0000-0000-0000-0000000000e1')
  and (select count(*) = 1 from public.events where series_id = 'e2000000-0000-0000-0000-0000000000e1'),
  'renommer garde l''occurrence supprimée et l''occurrence déplacée');
select is(
  (select title from public.events where id = 'e2000000-0000-0000-0000-0000000000e1'),
  'Yoga doux', 'le nouveau titre est pris');

-- Décaler d'une heure depuis l'hiver : 19 h locales, aussi en heure d'été -------------------
select lives_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e1', '2026-12-01 17:00+00',
    current_setting('agora_test.calendar')::uuid, 'Yoga doux', null, null,
    '2026-12-01 18:00+00', '2026-12-01 19:00+00', false, 'FREQ=WEEKLY;BYDAY=TU', null, false)$$,
  'on décale toute la série d''une heure');
select ok(
  (select starts_at = '2026-10-06 17:00+00' and ends_at = '2026-10-06 18:00+00'
   from public.events where id = 'e2000000-0000-0000-0000-0000000000e1'),
  'le premier rdv passe à 19 h, heure de Paris (17 h UTC en octobre)');
select ok(
  (select cardinality(exdates) = 0 from public.events where id = 'e2000000-0000-0000-0000-0000000000e1')
  and (select count(*) = 0 from public.events where series_id = 'e2000000-0000-0000-0000-0000000000e1'),
  'un nouvel horaire efface les exceptions');

-- Décaler d'un jour et allonger ------------------------------------------------------------------
select lives_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e1', '2026-12-08 18:00+00',
    current_setting('agora_test.calendar')::uuid, 'Yoga doux', null, null,
    '2026-12-09 18:00+00', '2026-12-09 20:00+00', false, 'FREQ=WEEKLY;BYDAY=WE', null, false)$$,
  'on décale toute la série au lendemain, sur deux heures');
select ok(
  (select starts_at = '2026-10-07 17:00+00' and ends_at = '2026-10-07 19:00+00'
     and rrule = 'FREQ=WEEKLY;BYDAY=WE'
   from public.events where id = 'e2000000-0000-0000-0000-0000000000e1'),
  'la série commence le mercredi 7 octobre à 19 h et dure deux heures');

-- Passer une série en journée entière -------------------------------------------------------------
select lives_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e1', '2026-12-09 18:00+00',
    current_setting('agora_test.calendar')::uuid, 'Yoga doux', null, null,
    '2026-12-09 00:00+00', '2026-12-10 00:00+00', true, 'FREQ=WEEKLY;BYDAY=WE', null, false)$$,
  'on passe la série en journée entière');
select ok(
  (select starts_at = '2026-10-07 00:00+00' and ends_at = '2026-10-08 00:00+00' and all_day
   from public.events where id = 'e2000000-0000-0000-0000-0000000000e1'),
  'elle couvre le 7 octobre entier, date lue dans son fuseau');

-- Série « journée entière » : dates en UTC -----------------------------------------------------------
select lives_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e2', '2026-10-13 00:00+00',
    current_setting('agora_test.calendar')::uuid, 'Garde', null, null,
    '2026-10-15 00:00+00', '2026-10-16 00:00+00', true, 'FREQ=WEEKLY', null, false)$$,
  'on décale une série journée entière de deux jours');
select ok(
  (select starts_at = '2026-10-08 00:00+00' and ends_at = '2026-10-09 00:00+00'
   from public.events where id = 'e2000000-0000-0000-0000-0000000000e2'),
  'elle commence deux jours plus tard');

-- Les jours de répétition suivent le décalage, compté dans le fuseau de la série ------------------
select lives_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e2', '2026-10-15 00:00+00',
    current_setting('agora_test.calendar')::uuid, 'Garde', null, null,
    '2026-10-16 00:00+00', '2026-10-17 00:00+00', true, 'FREQ=WEEKLY;BYDAY=TU,TH,SU', null, true)$$,
  'on décale une série d''un jour en laissant ses jours suivre');
select is(
  (select rrule from public.events where id = 'e2000000-0000-0000-0000-0000000000e2'),
  'FREQ=WEEKLY;BYDAY=MO,WE,FR', 'mardi, jeudi, dimanche deviennent mercredi, vendredi, lundi (triés)');
select lives_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e2', '2026-10-16 00:00+00',
    current_setting('agora_test.calendar')::uuid, 'Garde', null, null,
    '2026-10-14 00:00+00', '2026-10-15 00:00+00', true, 'FREQ=WEEKLY;BYDAY=MO,WE,FR', null, true)$$,
  'on la recule de deux jours');
select is(
  (select rrule from public.events where id = 'e2000000-0000-0000-0000-0000000000e2'),
  'FREQ=WEEKLY;BYDAY=MO,WE,SA', 'le décalage arrière fait le tour de la semaine');
select lives_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e2', '2026-10-14 00:00+00',
    current_setting('agora_test.calendar')::uuid, 'Garde', null, null,
    '2026-10-15 00:00+00', '2026-10-16 00:00+00', true, 'FREQ=MONTHLY;BYDAY=2TU', null, true)$$,
  'une règle avancée (jour ordinal) n''est pas réécrite');

-- Refus ------------------------------------------------------------------------------------------------
select throws_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e2', '2026-10-13 00:00+00',
    current_setting('agora_test.calendar')::uuid, 'Garde', null, null,
    '2026-10-16 00:00+00', '2026-10-15 00:00+00', true, 'FREQ=WEEKLY', null, false)$$,
  '22023', 'invalid_range', 'une fin avant le début est refusée');
select throws_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e3', '2026-10-08 08:00+00',
    current_setting('agora_test.calendar')::uuid, 'X', null, null,
    '2026-10-08 08:00+00', '2026-10-08 09:00+00', false, null, null, false)$$,
  'P0002', 'event_not_found', 'update_series ne vise que des séries');

set local request.jwt.claims = '{"sub":"66660000-0000-0000-0000-000000000006","role":"authenticated"}';
select throws_ok($$
  select public.update_series('e2000000-0000-0000-0000-0000000000e2', '2026-10-13 00:00+00',
    current_setting('agora_test.calendar')::uuid, 'Piraté', null, null,
    '2026-10-15 00:00+00', '2026-10-16 00:00+00', true, 'FREQ=WEEKLY', null, false)$$,
  'P0002', 'event_not_found', 'Paul ne modifie pas la série d''Inès');

select * from finish();
rollback;

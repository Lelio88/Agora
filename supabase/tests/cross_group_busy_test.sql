-- Règle de visibilité, volet inter-groupes : un rdv d'un autre groupe
-- auquel un membre a répondu « présent » le rend « occupé » ici — jamais
-- plus que « occupé » (le détail appartient à l'autre groupe), et dans la
-- limite de ce qu'il partage avec ce groupe-ci.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

-- Fixtures (en postgres) ------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('ab000000-0000-0000-0000-000000000001', 'alix@test.local', '{"display_name":"Alix"}'),
  ('ab000000-0000-0000-0000-000000000002', 'basile@test.local', '{"display_name":"Basile"}'),
  ('ab000000-0000-0000-0000-000000000003', 'cyril@test.local', '{"display_name":"Cyril"}'),
  ('ab000000-0000-0000-0000-000000000004', 'dora@test.local', '{"display_name":"Dora"}');

insert into public.groups (id, name) values
  ('ab100000-0000-0000-0000-000000000001', 'Potes'),
  ('ab200000-0000-0000-0000-000000000002', 'Foot');

-- Potes : Basile partage le détail, Dora ne partage rien. Foot : Basile,
-- Cyril (pas dans Potes) et Dora.
insert into public.group_members (group_id, user_id, role, share_level) values
  ('ab100000-0000-0000-0000-000000000001', 'ab000000-0000-0000-0000-000000000001', 'owner', 'details'),
  ('ab100000-0000-0000-0000-000000000001', 'ab000000-0000-0000-0000-000000000002', 'member', 'details'),
  ('ab100000-0000-0000-0000-000000000001', 'ab000000-0000-0000-0000-000000000004', 'member', 'invisible'),
  ('ab200000-0000-0000-0000-000000000002', 'ab000000-0000-0000-0000-000000000002', 'owner', 'details'),
  ('ab200000-0000-0000-0000-000000000002', 'ab000000-0000-0000-0000-000000000003', 'member', 'details'),
  ('ab200000-0000-0000-0000-000000000002', 'ab000000-0000-0000-0000-000000000004', 'member', 'details');

insert into public.calendars (id, owner_id, group_id, name) values
  ('ab300000-0000-0000-0000-000000000002', null, 'ab200000-0000-0000-0000-000000000002', 'Foot');

insert into public.events (id, calendar_id, title, location, starts_at, ends_at, rrule) values
  ('ab400000-0000-0000-0000-000000000001', 'ab300000-0000-0000-0000-000000000002', 'Match', 'Stade',
   '2026-10-07 18:00+00', '2026-10-07 20:00+00', null),
  ('ab400000-0000-0000-0000-000000000002', 'ab300000-0000-0000-0000-000000000002', 'Apéro', null,
   '2026-10-08 19:00+00', '2026-10-08 21:00+00', null),
  ('ab400000-0000-0000-0000-000000000003', 'ab300000-0000-0000-0000-000000000002', 'Entraînement', null,
   '2026-09-29 16:00+00', '2026-09-29 17:30+00', 'FREQ=WEEKLY');
insert into public.event_occurrences (event_id, starts_at, ends_at) values
  ('ab400000-0000-0000-0000-000000000003', '2026-10-06 16:00+00', '2026-10-06 17:30+00'),
  ('ab400000-0000-0000-0000-000000000003', '2026-10-13 16:00+00', '2026-10-13 17:30+00');

-- Basile vient au match et à l'entraînement du 6 ; peut-être à l'apéro.
-- Cyril et Dora viennent au match.
insert into public.event_responses (event_id, occurrence_start, user_id, status) values
  ('ab400000-0000-0000-0000-000000000001', null, 'ab000000-0000-0000-0000-000000000002', 'yes'),
  ('ab400000-0000-0000-0000-000000000002', null, 'ab000000-0000-0000-0000-000000000002', 'maybe'),
  ('ab400000-0000-0000-0000-000000000003', '2026-10-06 16:00+00', 'ab000000-0000-0000-0000-000000000002', 'yes'),
  ('ab400000-0000-0000-0000-000000000001', null, 'ab000000-0000-0000-0000-000000000003', 'yes'),
  ('ab400000-0000-0000-0000-000000000001', null, 'ab000000-0000-0000-0000-000000000004', 'yes');

-- Alix regarde les Potes -----------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"ab000000-0000-0000-0000-000000000001","role":"authenticated"}';

select results_eq(
  $$select starts_at, level::text, title, event_id::text from public.group_agenda(
      'ab100000-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
    where user_id = 'ab000000-0000-0000-0000-000000000002' order by starts_at$$,
  $$values ('2026-10-06 16:00+00'::timestamptz, 'busy', null::text, null::text),
           ('2026-10-07 18:00+00'::timestamptz, 'busy', null::text, null::text)$$,
  'Basile, présent au match et à l''entraînement du 6, est « occupé » chez les Potes');
select is(
  (select count(*)::int from public.group_agenda('ab100000-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where title in ('Match', 'Entraînement', 'Apéro') or location = 'Stade'), 0,
  'rien du rdv de Foot ne passe, bien que Basile partage le détail avec les Potes');
select is(
  (select count(*)::int from public.group_agenda('ab100000-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where user_id = 'ab000000-0000-0000-0000-000000000002' and starts_at = '2026-10-08 19:00+00'), 0,
  '« peut-être » ne rend pas occupé');
select is(
  (select count(*)::int from public.group_agenda('ab100000-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where user_id = 'ab000000-0000-0000-0000-000000000004'), 0,
  'Dora ne partage rien avec les Potes : sa présence au match n''y paraît pas');
select is(
  (select count(*)::int from public.group_agenda('ab100000-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where user_id = 'ab000000-0000-0000-0000-000000000003'), 0,
  'Cyril n''est pas des Potes : rien de lui');

-- Basile regarde les Potes : ses propres engagements en détail ---------------------------------------------
set local request.jwt.claims = '{"sub":"ab000000-0000-0000-0000-000000000002","role":"authenticated"}';
select is(
  (select title from public.group_agenda('ab100000-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where user_id = 'ab000000-0000-0000-0000-000000000002' and starts_at = '2026-10-07 18:00+00'),
  'Match', 'Basile voit le titre de son propre engagement');

-- Dans Foot, le match reste un seul rdv du groupe ---------------------------------------------------------------
select is(
  (select count(*)::int from public.group_agenda('ab200000-0000-0000-0000-000000000002', '2026-10-05', '2026-10-12')
   where starts_at = '2026-10-07 18:00+00'), 1,
  'dans son propre groupe, le match n''est pas doublé par les présences');

-- Pour Discord : plafond « occupé » ------------------------------------------------------------------------------
reset role;
select is(
  (select level::text from private.resolve_group_agenda('ab100000-0000-0000-0000-000000000001', null,
     '2026-10-05', '2026-10-12', 'busy')
   where user_id = 'ab000000-0000-0000-0000-000000000002' and starts_at = '2026-10-07 18:00+00'),
  'busy', 'une publication Discord montre la présence en « occupé »');

-- Quitter Foot efface ses réponses : plus rien chez les Potes ---------------------------------------------------
delete from public.group_members
where group_id = 'ab200000-0000-0000-0000-000000000002' and user_id = 'ab000000-0000-0000-0000-000000000002';
select is(
  (select count(*)::int from private.resolve_group_agenda('ab100000-0000-0000-0000-000000000001',
     'ab000000-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12', 'details')
   where user_id = 'ab000000-0000-0000-0000-000000000002'), 0,
  'Basile parti de Foot, ses présences ne comptent plus');

select * from finish();
rollback;

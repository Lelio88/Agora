-- Règle de visibilité : ce que chaque membre voit des rdv des autres.
-- Voir l'en-tête de la migration core_schema pour la règle elle-même.
begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

-- Fixtures (en postgres) ------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@test.local', '{"display_name":"Alice"}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@test.local',   '{"display_name":"Bob"}'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@test.local', '{"display_name":"Carol"}');

insert into public.groups (id, name) values
  ('11111111-0000-0000-0000-000000000001', 'Potes'),
  ('22222222-0000-0000-0000-000000000002', 'Famille');

-- Bob montre le détail aux Potes, seulement « occupé » à la Famille.
insert into public.group_members (group_id, user_id, role, share_level) values
  ('11111111-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'owner',  'details'),
  ('11111111-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'member', 'details'),
  ('22222222-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'owner',  'busy'),
  ('22222222-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000003', 'member', 'details');

insert into public.calendars (id, owner_id, group_id, name, visibility) values
  ('b1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', null, 'Perso', null),
  ('b2000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', null, 'Travail', 'busy'),
  ('c1000000-0000-0000-0000-000000000001', null, '11111111-0000-0000-0000-000000000001', 'Potes', null);

insert into public.events (id, calendar_id, title, location, starts_at, ends_at, visibility, rrule) values
  ('e1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Cinéma', 'Pathé',
   '2026-10-06 18:00+00', '2026-10-06 20:00+00', null, null),
  ('e2000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', 'Dentiste', null,
   '2026-10-07 09:00+00', '2026-10-07 10:00+00', 'busy', null),
  ('e3000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000001', 'Secret', null,
   '2026-10-07 14:00+00', '2026-10-07 15:00+00', 'invisible', null),
  ('e4000000-0000-0000-0000-000000000004', 'b2000000-0000-0000-0000-000000000002', 'Réunion', null,
   '2026-10-08 10:00+00', '2026-10-08 11:00+00', null, null),
  ('e5000000-0000-0000-0000-000000000005', 'b1000000-0000-0000-0000-000000000001', 'Sport', null,
   '2026-09-01 07:00+00', '2026-09-01 08:00+00', null, 'FREQ=WEEKLY;BYDAY=TU'),
  ('e9000000-0000-0000-0000-000000000009', 'c1000000-0000-0000-0000-000000000001', 'Resto', 'Chez Paul',
   '2026-10-09 19:00+00', '2026-10-09 22:00+00', null, null);

-- Occurrences dépliées par le worker ; une seule tombe dans la semaine testée.
insert into public.event_occurrences (event_id, starts_at, ends_at) values
  ('e5000000-0000-0000-0000-000000000005', '2026-09-29 07:00+00', '2026-09-29 08:00+00'),
  ('e5000000-0000-0000-0000-000000000005', '2026-10-06 07:00+00', '2026-10-06 08:00+00'),
  ('e5000000-0000-0000-0000-000000000005', '2026-10-13 07:00+00', '2026-10-13 08:00+00');

-- Alice regarde les Potes ------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}';

select is(
  (select count(*)::int from public.group_agenda(
    '11111111-0000-0000-0000-000000000001', '2026-10-05 00:00+00', '2026-10-12 00:00+00')),
  5, 'Alice voit 5 créneaux : Cinéma, Dentiste, Réunion, Sport, Resto');

select is(
  (select title from public.group_agenda(
    '11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where starts_at = '2026-10-06 18:00+00'),
  'Cinéma', 'un rdv qui hérite du partage « détails » montre son titre');

select ok(
  (select level = 'busy' and title is null and event_id is null and location is null
   from public.group_agenda('11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where starts_at = '2026-10-07 09:00+00'),
  'un rdv « occupé » ne livre ni titre, ni lieu, ni identifiant');

select is(
  (select count(*)::int from public.group_agenda(
    '11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where starts_at = '2026-10-07 14:00+00'),
  0, 'un rdv « invisible » n''existe pas pour les autres');

select is(
  (select level from public.group_agenda(
    '11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where starts_at = '2026-10-08 10:00+00'),
  'busy'::public.visibility, 'le réglage « occupé » de l''agenda Travail s''applique à ses rdv');

select results_eq(
  $$select starts_at from public.group_agenda(
      '11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
    where title = 'Sport'$$,
  $$values ('2026-10-06 07:00+00'::timestamptz)$$,
  'un rdv récurrent apparaît par ses occurrences dans la plage, pas par sa date d''origine');

select ok(
  (select is_group_event and user_id is null and title = 'Resto'
   from public.group_agenda('11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where starts_at = '2026-10-09 19:00+00'),
  'un rdv de groupe est en détail pour tous, sans propriétaire');

select is(
  (select count(*)::int from public.events
   where calendar_id in ('b1000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000002')),
  0, 'Alice ne lit pas les rdv de Bob en direct dans la table');

select is(
  (select count(*)::int from public.event_occurrences
   where event_id = 'e5000000-0000-0000-0000-000000000005'),
  0, 'Alice ne lit pas les occurrences de Bob en direct');

select throws_ok(
  $$select * from private.calendar_feeds$$,
  '42501', null, 'aucun client ne lit les URL iCal');

select throws_ok(
  $$select * from public.group_agenda('11111111-0000-0000-0000-000000000001', '2026-01-01', '2026-06-01')$$,
  '22023', 'invalid_range', 'une plage de plus d''un trimestre est refusée');

select throws_ok(
  $$select public.set_event_visibility('e1000000-0000-0000-0000-000000000001', 'busy')$$,
  'P0002', 'event_not_found', 'on ne masque pas le rdv d''un autre');

-- Carol regarde la Famille, où Bob ne partage que « occupé » -------------------
set local request.jwt.claims = '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}';

select ok(
  (select count(*) = 4 and bool_and(level = 'busy' and title is null)
   from public.group_agenda('22222222-0000-0000-0000-000000000002', '2026-10-05', '2026-10-12')),
  'le partage « occupé » d''un groupe plafonne tous les rdv de Bob, sans rien cacher de plus');

select throws_ok(
  $$select * from public.group_agenda('11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')$$,
  '42501', 'not_a_member', 'un non-membre ne lit pas l''agenda d''un groupe');

-- Bob regarde les Potes et masque un rdv ---------------------------------------
set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}';

select is(
  (select title from public.group_agenda(
    '11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')
   where starts_at = '2026-10-07 14:00+00'),
  'Secret', 'le propriétaire voit ses propres rdv, même invisibles');

select public.set_event_visibility('e1000000-0000-0000-0000-000000000001', 'invisible');

set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}';
select is(
  (select count(*)::int from public.group_agenda(
    '11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')),
  4, 'après masquage par Bob, Alice ne voit plus le Cinéma');

-- Accès anonyme ----------------------------------------------------------------
set local role anon;
select throws_ok(
  $$select * from public.group_agenda('11111111-0000-0000-0000-000000000001', '2026-10-05', '2026-10-12')$$,
  '42501', null, 'anon n''appelle pas group_agenda');

-- Plafond Discord (appel du worker) --------------------------------------------
reset role;
select is(
  (select array_agg(title order by starts_at) filter (where level = 'details')
   from private.resolve_group_agenda(
     '11111111-0000-0000-0000-000000000001', null,
     '2026-10-05', '2026-10-12', 'busy')),
  array['Resto'], 'pour Discord, seuls les rdv de groupe gardent leur détail');

select * from finish();
rollback;

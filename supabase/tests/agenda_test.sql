-- Agenda perso : lecture de l'agenda, séries et exceptions (occurrence
-- modifiée ou supprimée), notifications au worker, rôle agora_worker.
begin;
create extension if not exists pgtap with schema extensions;
select plan(36);

insert into auth.users (id, email, raw_user_meta_data) values
  ('11110000-0000-0000-0000-000000000001', 'nina@test.local', '{"display_name":"Nina"}'),
  ('22220000-0000-0000-0000-000000000002', 'omar@test.local', '{"display_name":"Omar"}');

-- Série hebdomadaire de Nina (mardi 18h, Paris) et ce que le worker aurait
-- déplié ; plus un rdv ponctuel. Insérés en postgres pour fixer les ids.
insert into public.events (id, calendar_id, title, starts_at, ends_at, timezone, rrule, created_by)
select 'e0000000-0000-0000-0000-0000000000a1', c.id, 'Yoga',
       '2026-10-06 16:00+00', '2026-10-06 17:00+00', 'Europe/Paris', 'FREQ=WEEKLY', c.owner_id
from public.calendars c where c.owner_id = '11110000-0000-0000-0000-000000000001';
insert into public.event_occurrences (event_id, starts_at, ends_at) values
  ('e0000000-0000-0000-0000-0000000000a1', '2026-10-06 16:00+00', '2026-10-06 17:00+00'),
  ('e0000000-0000-0000-0000-0000000000a1', '2026-10-13 16:00+00', '2026-10-13 17:00+00'),
  ('e0000000-0000-0000-0000-0000000000a1', '2026-10-20 16:00+00', '2026-10-20 17:00+00');
insert into public.events (id, calendar_id, title, starts_at, ends_at, created_by)
select 'e0000000-0000-0000-0000-0000000000b2', c.id, 'Dentiste',
       '2026-10-08 08:00+00', '2026-10-08 09:00+00', c.owner_id
from public.calendars c where c.owner_id = '11110000-0000-0000-0000-000000000001';

-- Structure -------------------------------------------------------------------
select has_trigger('public', 'events', 'events_notify_recurrence',
  'chaque changement de série notifie le worker');
select set_eq(
  $$select tablename::text from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename in ('events', 'event_occurrences', 'series_expansions')$$,
  array['events', 'series_expansions'],
  'temps réel : rdv et séries redépliées ; jamais les occurrences, dont les suppressions fuiraient l''horaire à tous');
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relname in ('events', 'series_expansions')
     and c.relreplident = 'f'),
  0, 'aucune table publiée en REPLICA IDENTITY FULL (les suppressions ignorent la RLS)');

-- Nina lit son agenda --------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"11110000-0000-0000-0000-000000000001","role":"authenticated"}';

select is(
  (select count(*)::int from public.my_agenda('2026-10-05', '2026-10-19')),
  3, 'deux occurrences de Yoga et le Dentiste, jamais la ligne maîtresse de la série');

select ok(
  (select bool_and(series_id = 'e0000000-0000-0000-0000-0000000000a1'
                   and original_start = starts_at and rrule = 'FREQ=WEEKLY')
   from public.my_agenda('2026-10-05', '2026-10-19') where title = 'Yoga'),
  'une occurrence porte sa série, son créneau d''origine et la règle');

select ok(
  (select series_id is null and original_start is null
   from public.my_agenda('2026-10-05', '2026-10-19') where title = 'Dentiste'),
  'un rdv ponctuel n''a ni série ni créneau d''origine');

select throws_ok($$select * from public.my_agenda('2026-01-01', '2026-06-01')$$,
  '22023', 'invalid_range', 'la plage est bornée à un trimestre');

-- Occurrence modifiée ----------------------------------------------------------------
select lives_ok($$
  insert into public.events (series_id, recurrence_id, calendar_id, title, starts_at, ends_at, timezone)
  select id, '2026-10-13 16:00+00', calendar_id, 'Yoga (décalé)',
         '2026-10-13 18:00+00', '2026-10-13 19:00+00', timezone
  from public.events where id = 'e0000000-0000-0000-0000-0000000000a1'$$,
  'on modifie une seule occurrence de sa série');

select ok(
  (select series_id = 'e0000000-0000-0000-0000-0000000000a1'
          and original_start = '2026-10-13 16:00+00'
   from public.my_agenda('2026-10-05', '2026-10-19') where title = 'Yoga (décalé)'),
  'l''occurrence modifiée garde le lien vers sa série et son créneau d''origine');

select throws_ok($$
  insert into public.events (series_id, recurrence_id, calendar_id, title, starts_at, ends_at)
  select id, '2026-10-13 16:00+00', calendar_id, 'Doublon', now(), now()
  from public.events where id = 'e0000000-0000-0000-0000-0000000000a1'$$,
  '23505', null, 'un créneau d''une série ne se modifie qu''une fois');

select throws_ok($$
  insert into public.events (series_id, recurrence_id, calendar_id, title, starts_at, ends_at)
  select id, '2026-10-08 08:00+00', calendar_id, 'Pas une série', now(), now()
  from public.events where id = 'e0000000-0000-0000-0000-0000000000b2'$$,
  '22023', 'invalid_series', 'on ne rattache pas une exception à un rdv ponctuel');

select throws_ok($$
  insert into public.events (series_id, calendar_id, title, starts_at, ends_at)
  select id, calendar_id, 'Sans créneau', now(), now()
  from public.events where id = 'e0000000-0000-0000-0000-0000000000a1'$$,
  '23514', null, 'une exception a toujours un créneau d''origine');

-- Occurrence modifiée par la RPC (remplace une modification précédente) ------------------
select lives_ok($$
  select public.replace_occurrence(
    'e0000000-0000-0000-0000-0000000000a1', '2026-10-13 16:00+00',
    'Yoga (encore décalé)', null, null, '2026-10-13 19:00+00', '2026-10-13 20:00+00', false, null)$$,
  'replace_occurrence remplace l''occurrence déjà modifiée du même créneau');

select is(
  (select count(*)::int from public.events
   where series_id = 'e0000000-0000-0000-0000-0000000000a1' and recurrence_id = '2026-10-13 16:00+00'),
  1, 'un seul remplaçant subsiste pour ce créneau');

select is(
  (select title from public.my_agenda('2026-10-05', '2026-10-19') where starts_at = '2026-10-13 19:00+00'),
  'Yoga (encore décalé)', 'l''agenda montre le dernier remplaçant');

select throws_ok($$
  select public.replace_occurrence(
    'e0000000-0000-0000-0000-0000000000b2', '2026-10-08 08:00+00',
    'X', null, null, now(), now(), false, null)$$,
  'P0002', 'event_not_found', 'replace_occurrence refuse un rdv ponctuel');

-- Occurrence supprimée ---------------------------------------------------------------
select lives_ok($$select public.delete_occurrence('e0000000-0000-0000-0000-0000000000a1', '2026-10-20 16:00+00')$$,
  'on supprime une seule occurrence');
select lives_ok($$select public.delete_occurrence('e0000000-0000-0000-0000-0000000000a1', '2026-10-13 16:00+00')$$,
  'supprimer une occurrence modifiée l''efface aussi');

reset role;
select is(
  (select exdates from public.events where id = 'e0000000-0000-0000-0000-0000000000a1'),
  array['2026-10-20 16:00+00', '2026-10-13 16:00+00']::timestamptz[],
  'chaque occurrence supprimée devient une exception de la série');
select is(
  (select count(*)::int from public.events where series_id = 'e0000000-0000-0000-0000-0000000000a1'),
  0, 'l''occurrence modifiée supprimée n''existe plus');

-- Changer l'horaire de la série efface les exceptions ----------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"11110000-0000-0000-0000-000000000001","role":"authenticated"}';
insert into public.events (series_id, recurrence_id, calendar_id, title, starts_at, ends_at)
select id, '2026-10-27 16:00+01', calendar_id, 'Yoga (exception)', '2026-10-27 18:00+01', '2026-10-27 19:00+01'
from public.events where id = 'e0000000-0000-0000-0000-0000000000a1';

update public.events set title = 'Yoga doux' where id = 'e0000000-0000-0000-0000-0000000000a1';
select is(
  (select count(*)::int from public.events where series_id = 'e0000000-0000-0000-0000-0000000000a1'),
  1, 'renommer la série garde ses exceptions');

update public.events set starts_at = starts_at + interval '1 hour', ends_at = ends_at + interval '1 hour'
where id = 'e0000000-0000-0000-0000-0000000000a1';
select ok(
  (select exdates = '{}' from public.events where id = 'e0000000-0000-0000-0000-0000000000a1')
  and (select count(*) = 0 from public.events where series_id = 'e0000000-0000-0000-0000-0000000000a1'),
  'changer l''horaire de la série efface occurrences modifiées et supprimées');

update public.events set rrule = null where id = 'e0000000-0000-0000-0000-0000000000a1';
select is(
  (select count(*)::int from public.my_agenda('2026-10-05', '2026-10-19') where title = 'Yoga doux'),
  1, 'une série redevenue ponctuelle n''a plus d''occurrences dépliées');

-- Omar ne touche pas aux rdv de Nina ------------------------------------------------------------
set local request.jwt.claims = '{"sub":"22220000-0000-0000-0000-000000000002","role":"authenticated"}';
select is((select count(*)::int from public.my_agenda('2026-10-05', '2026-10-19')), 0,
  'l''agenda d''Omar ne contient rien de Nina');
select throws_ok($$select public.delete_occurrence('e0000000-0000-0000-0000-0000000000a1', '2026-10-06 16:00+00')$$,
  'P0002', 'event_not_found', 'Omar ne supprime pas une occurrence de Nina');

-- Agenda de groupe : un membre n'agit pas sur la série d'un autre --------------------------------
reset role;
insert into public.groups (id, name) values ('90000000-0000-0000-0000-000000000009', 'Coloc');
insert into public.group_members (group_id, user_id, role) values
  ('90000000-0000-0000-0000-000000000009', '11110000-0000-0000-0000-000000000001', 'owner'),
  ('90000000-0000-0000-0000-000000000009', '22220000-0000-0000-0000-000000000002', 'member');
insert into public.calendars (id, owner_id, group_id, name)
values ('c0000000-0000-0000-0000-00000000000c', null, '90000000-0000-0000-0000-000000000009', 'Coloc');
insert into public.events (id, calendar_id, title, starts_at, ends_at, timezone, rrule, created_by)
values ('e0000000-0000-0000-0000-0000000000c3', 'c0000000-0000-0000-0000-00000000000c', 'Ménage',
        '2026-10-10 08:00+00', '2026-10-10 09:00+00', 'Europe/Paris', 'FREQ=WEEKLY',
        '11110000-0000-0000-0000-000000000001');
insert into public.event_occurrences (event_id, starts_at, ends_at) values
  ('e0000000-0000-0000-0000-0000000000c3', '2026-10-10 08:00+00', '2026-10-10 09:00+00');
insert into public.series_expansions (series_id) values ('e0000000-0000-0000-0000-0000000000c3');

set local role authenticated;
set local request.jwt.claims = '{"sub":"22220000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok($$
  insert into public.events (series_id, recurrence_id, calendar_id, title, starts_at, ends_at)
  values ('e0000000-0000-0000-0000-0000000000c3', '2026-10-10 08:00+00',
          'c0000000-0000-0000-0000-00000000000c', 'Annulé', now(), now())$$,
  '22023', 'invalid_series',
  'un membre ne rattache pas d''occurrence modifiée à la série d''un autre membre');
select is(
  (select count(*)::int from public.my_agenda('2026-10-05', '2026-10-19') where title = 'Ménage'),
  1, 'l''occurrence de la série attaquée est toujours là');
select is((select count(*)::int from public.series_expansions), 1,
  'un membre du groupe voit le signal de dépliage des séries du groupe');

set local request.jwt.claims = '{"sub":"11110000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(
  (select count(*)::int from public.series_expansions where series_id = 'e0000000-0000-0000-0000-0000000000c3'),
  1, 'la créatrice de la série voit son signal de dépliage');

reset role;
delete from public.group_members where user_id = '22220000-0000-0000-0000-000000000002';
set local role authenticated;
set local request.jwt.claims = '{"sub":"22220000-0000-0000-0000-000000000002","role":"authenticated"}';
select is((select count(*)::int from public.series_expansions), 0,
  'hors du groupe, plus aucun signal de dépliage');

-- Rôle du worker ---------------------------------------------------------------------------------
reset role;
-- Pour appeler pgTAP sous ce rôle ; annulé avec la transaction du test.
grant usage on schema extensions to agora_worker;
set local role agora_worker;
select ok((select count(id) >= 2 from public.events),
  'le worker lit les horaires des rdv de tout le monde');
select throws_ok($$select title from public.events$$, '42501', null,
  'le worker ne lit jamais le titre d''un rdv');
select lives_ok($$insert into public.event_occurrences (event_id, starts_at, ends_at)
  values ('e0000000-0000-0000-0000-0000000000b2', '2027-01-01', '2027-01-01')$$,
  'le worker écrit les occurrences');
select lives_ok($$
  insert into public.series_expansions (series_id) values ('e0000000-0000-0000-0000-0000000000c3')
  on conflict (series_id) do update set expanded_at = excluded.expanded_at$$,
  'le worker signale une série redépliée');
select throws_ok($$update public.events set title = 'Piraté'$$, '42501', null,
  'le worker ne modifie pas les rdv');
select throws_ok($$select * from public.profiles$$, '42501', null,
  'le worker ne lit pas les profils');

select * from finish();
rollback;

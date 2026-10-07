-- Rdv semblables : modifier un rdv ponctuel peut recopier ce qui a changé
-- (titre, lieu, description, visibilité, agenda) sur les rdv ponctuels du
-- même agenda, de même titre, au même jour de la semaine et à la même heure
-- locale, à partir de lui. Jamais la date ni l'heure, jamais une série,
-- jamais hors de ses propres agendas.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

insert into auth.users (id, email, raw_user_meta_data) values
  ('55550000-0000-0000-0000-000000000005', 'ines@test.local', '{"display_name":"Inès"}'),
  ('66660000-0000-0000-0000-000000000006', 'paul@test.local', '{"display_name":"Paul"}');
select set_config('agora_test.perso',
  (select id::text from public.calendars where owner_id = '55550000-0000-0000-0000-000000000005'), true);
insert into public.calendars (id, owner_id, name) values
  ('c1000000-0000-0000-0000-0000000000f1', '55550000-0000-0000-0000-000000000005', 'Fac');

-- Le TD d'Inès, le lundi à 8 h à Paris (6 h UTC en heure d'été, 7 h en hiver),
-- et ce qui lui ressemble sans être semblable.
insert into public.events (id, calendar_id, title, location, description, starts_at, ends_at,
                           all_day, timezone, rrule, created_by)
select v.id::uuid, coalesce(v.calendar_id::uuid, current_setting('agora_test.perso')::uuid),
       v.title, 'UTT', v.description, v.starts_at::timestamptz, v.ends_at::timestamptz,
       v.all_day, 'Europe/Paris', v.rrule, '55550000-0000-0000-0000-000000000005'
from (values
  ('f1000000-0000-0000-0000-000000000001', null, 'NF19 — TD', 'Séance 1',
   '2026-10-05 06:00+00', '2026-10-05 08:00+00', false, null),        -- le rdv ouvert
  ('f1000000-0000-0000-0000-000000000002', null, 'NF19 — TD', 'Séance 0',
   '2026-09-28 06:00+00', '2026-09-28 08:00+00', false, null),        -- avant lui
  ('f1000000-0000-0000-0000-000000000003', null, 'NF19 — TD', 'Séance 2',
   '2026-10-12 06:00+00', '2026-10-12 08:00+00', false, null),        -- semblable
  ('f1000000-0000-0000-0000-000000000004', null, 'NF19 — TD', 'Séance 3',
   '2026-11-02 07:00+00', '2026-11-02 09:00+00', false, null),        -- semblable, en hiver
  ('f1000000-0000-0000-0000-000000000005', null, 'NF19 — TD', 'Autre groupe',
   '2026-10-14 12:00+00', '2026-10-14 14:00+00', false, null),        -- un mercredi
  ('f1000000-0000-0000-0000-000000000006', null, 'NF19 — TD', 'Plus tard',
   '2026-10-19 08:00+00', '2026-10-19 10:00+00', false, null),        -- lundi, 10 h
  ('f1000000-0000-0000-0000-000000000007', null, 'NF19 — CM', 'Cours',
   '2026-10-12 06:00+00', '2026-10-12 08:00+00', false, null),        -- autre titre
  ('f1000000-0000-0000-0000-000000000008', 'c1000000-0000-0000-0000-0000000000f1', 'NF19 — TD', null,
   '2026-10-12 06:00+00', '2026-10-12 08:00+00', false, null),        -- autre agenda
  ('f1000000-0000-0000-0000-000000000009', null, 'NF19 — TD', null,
   '2026-10-05 06:00+00', '2026-10-05 08:00+00', false, 'FREQ=WEEKLY;BYDAY=MO'), -- une série
  ('f1000000-0000-0000-0000-000000000010', null, 'NF19 — TD', null,
   '2026-10-19 00:00+00', '2026-10-20 00:00+00', true, null),         -- journée entière, lundi
  ('f1000000-0000-0000-0000-000000000014', null, 'NF19 — TD', null,
   '2026-10-26 00:00+00', '2026-10-27 00:00+00', true, null)          -- idem, une semaine après
) as v(id, calendar_id, title, description, starts_at, ends_at, all_day, rrule);

-- Le même cours chez Paul.
insert into public.events (id, calendar_id, title, location, starts_at, ends_at, created_by)
select 'f1000000-0000-0000-0000-000000000011', c.id, 'NF19 — TD', 'UTT',
       '2026-10-12 06:00+00', '2026-10-12 08:00+00', '66660000-0000-0000-0000-000000000006'
from public.calendars c where c.owner_id = '66660000-0000-0000-0000-000000000006';

-- Un agenda de groupe où Inès est propriétaire : le rdv de Paul n'est pas le sien.
insert into public.groups (id, name) values ('90000000-0000-0000-0000-000000000009', 'Promo');
insert into public.group_members (group_id, user_id, role) values
  ('90000000-0000-0000-0000-000000000009', '55550000-0000-0000-0000-000000000005', 'owner'),
  ('90000000-0000-0000-0000-000000000009', '66660000-0000-0000-0000-000000000006', 'member');
insert into public.calendars (id, owner_id, group_id, name)
values ('c1000000-0000-0000-0000-0000000000f2', null, '90000000-0000-0000-0000-000000000009', 'Promo');
insert into public.events (id, calendar_id, title, location, starts_at, ends_at, created_by) values
  ('f1000000-0000-0000-0000-000000000012', 'c1000000-0000-0000-0000-0000000000f2', 'Révisions', 'BU',
   '2026-10-05 16:00+00', '2026-10-05 18:00+00', '55550000-0000-0000-0000-000000000005'),
  ('f1000000-0000-0000-0000-000000000013', 'c1000000-0000-0000-0000-0000000000f2', 'Révisions', 'BU',
   '2026-10-12 16:00+00', '2026-10-12 18:00+00', '66660000-0000-0000-0000-000000000006');

set local role authenticated;
set local request.jwt.claims = '{"sub":"55550000-0000-0000-0000-000000000005","role":"authenticated"}';

-- Qui est semblable ------------------------------------------------------------------------------
select is(public.count_similar_events('f1000000-0000-0000-0000-000000000001'), 2,
  'semblables : même agenda, même titre, même jour et même heure locale (été comme hiver), à partir de lui');
select is(public.count_similar_events('f1000000-0000-0000-0000-000000000010'), 1,
  'une journée entière se compare aux journées entières du même jour de la semaine');
select is(public.count_similar_events('f1000000-0000-0000-0000-000000000009'), 0,
  'une série n''a pas de semblables : elle a déjà « toute la série »');
select is(public.count_similar_events('f1000000-0000-0000-0000-000000000012'), 0,
  'jamais dans un agenda de groupe : le rdv d''un autre membre n''y passe pas');

-- Recopier le lieu -------------------------------------------------------------------------------
select is(
  public.update_similar_events('f1000000-0000-0000-0000-000000000001', array['location'],
    current_setting('agora_test.perso')::uuid, 'NF19 — TD', ' 12 rue Marie Curie ', 'Ignorée', null),
  2, 'le lieu est recopié sur les deux semblables');
select is(
  (select array_agg(id order by id) from public.events where location = '12 rue Marie Curie'),
  array['f1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000004']::uuid[],
  'seuls les semblables changent ; le rdv ouvert attend l''app, qui l''enregistre ensuite');
select is(
  (select array_agg(description order by starts_at) from public.events
   where id in ('f1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000004')),
  array['Séance 2', 'Séance 3'],
  'un champ non nommé ne bouge pas : chaque séance garde sa description');
select is(
  (select array_agg(starts_at order by starts_at) from public.events
   where id in ('f1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000004')),
  array['2026-10-12 06:00+00', '2026-11-02 07:00+00']::timestamptz[],
  'ni la date ni l''heure ne sont recopiées');

-- Recopier titre et visibilité -------------------------------------------------------------------
select is(
  public.update_similar_events('f1000000-0000-0000-0000-000000000001', array['title', 'visibility'],
    current_setting('agora_test.perso')::uuid, '  NF19 — TD (amphi) ', null, null, 'busy'),
  2, 'titre et visibilité sont recopiés');
select ok(
  (select bool_and(title = 'NF19 — TD (amphi)' and visibility = 'busy'
                   and location = '12 rue Marie Curie')
   from public.events
   where id in ('f1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000004')),
  'le titre est nettoyé, la visibilité prise, le lieu déjà recopié gardé');
select is(public.count_similar_events('f1000000-0000-0000-0000-000000000001'), 0,
  'les semblables se cherchent sur le rdv tel qu''il est enregistré : renommés, ils ne le sont plus');

-- Recopier l'agenda ------------------------------------------------------------------------------
update public.events set title = 'NF19 — TD (amphi)' where id = 'f1000000-0000-0000-0000-000000000001';
select is(
  public.update_similar_events('f1000000-0000-0000-0000-000000000001', array['calendar'],
    'c1000000-0000-0000-0000-0000000000f1', 'NF19 — TD (amphi)', null, null, null),
  2, 'une fois le rdv ouvert renommé par l''app, ses semblables le suivent dans un autre agenda');
select is(
  (select count(*)::integer from public.events
   where calendar_id = 'c1000000-0000-0000-0000-0000000000f1' and title = 'NF19 — TD (amphi)'),
  2, 'les deux semblables sont dans l''agenda Fac');

-- Refus ------------------------------------------------------------------------------------------
select throws_ok($$
  select public.update_similar_events('f1000000-0000-0000-0000-000000000001', array['starts_at'],
    current_setting('agora_test.perso')::uuid, 'X', null, null, null)$$,
  '22023', 'invalid_fields', 'un champ hors de la liste (date, heure…) est refusé');
select throws_ok($$
  select public.update_similar_events('f1000000-0000-0000-0000-000000000009', array['location'],
    current_setting('agora_test.perso')::uuid, 'NF19 — TD', 'Ailleurs', null, null)$$,
  'P0002', 'event_not_found', 'une série ne passe pas par ici');
select is(
  public.update_similar_events('f1000000-0000-0000-0000-000000000012', array['location'],
    'c1000000-0000-0000-0000-0000000000f2', 'Révisions', 'Salle 12', null, null),
  0, 'dans un agenda de groupe, rien n''est recopié');
select is(
  (select location from public.events where id = 'f1000000-0000-0000-0000-000000000013'),
  'BU', 'le rdv de Paul dans le groupe garde son lieu');
select is(public.update_similar_events('f1000000-0000-0000-0000-000000000001', array[]::text[],
    current_setting('agora_test.perso')::uuid, 'NF19 — TD (amphi)', null, null, null),
  0, 'sans champ nommé, rien ne bouge');

set local request.jwt.claims = '{"sub":"66660000-0000-0000-0000-000000000006","role":"authenticated"}';
select is(public.count_similar_events('f1000000-0000-0000-0000-000000000001'), 0,
  'Paul ne compte pas les rdv d''Inès');
select throws_ok($$
  select public.update_similar_events('f1000000-0000-0000-0000-000000000001', array['location'],
    current_setting('agora_test.perso')::uuid, 'NF19 — TD', 'Piraté', null, null)$$,
  'P0002', 'event_not_found', 'Paul ne modifie pas les rdv d''Inès');

select * from finish();
rollback;

-- Inscription, groupes, invitations, agendas iCal et droits d'écriture.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, email, raw_user_meta_data) values
  ('eeeeeeee-0000-0000-0000-000000000005', 'eve@test.local',   '{"full_name":"Eve Martin"}'),
  ('ffffffff-0000-0000-0000-000000000006', 'frank@test.local', '{"custom_claims":{"global_name":"Frankie"},"name":"frank_42"}'),
  ('99999999-0000-0000-0000-000000000009', 'jean.dupont@test.local', null);

-- Inscription -------------------------------------------------------------------
select is(
  (select display_name from public.profiles where id = 'eeeeeeee-0000-0000-0000-000000000005'),
  'Eve Martin', 'le nom vient des métadonnées du fournisseur');

select is(
  (select display_name from public.profiles where id = 'ffffffff-0000-0000-0000-000000000006'),
  'Frankie', 'un compte Discord prend son nom d''affichage, pas son identifiant');

select is(
  (select display_name from public.profiles where id = '99999999-0000-0000-0000-000000000009'),
  'Membre', 'sans métadonnées, le nom ne reprend jamais l''adresse e-mail');

select is(
  (select count(*)::int from public.calendars
   where owner_id = 'eeeeeeee-0000-0000-0000-000000000005' and kind = 'native' and name = 'Agenda'),
  1, 'chaque inscrit reçoit un agenda natif par défaut');

-- Eve crée un groupe et invite Frank ---------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"eeeeeeee-0000-0000-0000-000000000005","role":"authenticated"}';

select lives_ok($$select public.create_group('Randonnée', 'Sorties du dimanche')$$,
  'create_group réussit');

select ok(
  (select role = 'owner' and share_level = 'busy' from public.group_members
   where user_id = 'eeeeeeee-0000-0000-0000-000000000005'),
  'le créateur est propriétaire et ne partage que « occupé » par défaut');

select is(
  (select count(*)::int from public.calendars c join public.groups g on g.id = c.group_id
   where g.name = 'Randonnée'),
  1, 'le groupe reçoit son agenda partagé');

select throws_ok(
  $$insert into public.groups (name) values ('Pirate')$$,
  '42501', null, 'on ne crée pas de groupe en direct, seulement par create_group');

-- Le code voyage hors de la base (lien partagé) : on le garde en variable.
select set_config('agora_test.code',
  public.create_invite((select id from public.groups where name = 'Randonnée')), true);
select matches(current_setting('agora_test.code'),
  '^[A-HJ-NP-Z2-9]{8}$', 'un code d''invitation fait 8 caractères non ambigus');

-- Frank rejoint -------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"ffffffff-0000-0000-0000-000000000006","role":"authenticated"}';

select set_config('agora_test.joined',
  public.join_group(lower(current_setting('agora_test.code')))::text, true);
select is(
  current_setting('agora_test.joined')::uuid,
  (select id from public.groups where name = 'Randonnée'),
  'join_group accepte le code, casse ignorée');

select ok(
  (select role = 'member' and share_level = 'busy' from public.group_members
   where user_id = 'ffffffff-0000-0000-0000-000000000006'),
  'le nouveau membre entre en simple membre, en « occupé »');

select throws_ok($$select public.join_group('ZZZZZZZZ')$$,
  'P0002', 'invite_invalid', 'un code inconnu est refusé');

select throws_ok(
  $$update public.group_members set role = 'owner'
    where user_id = 'ffffffff-0000-0000-0000-000000000006'$$,
  '42501', null, 'un membre ne peut pas changer son rôle');

select lives_ok(
  $$update public.group_members set share_level = 'details'
    where user_id = 'ffffffff-0000-0000-0000-000000000006'$$,
  'un membre règle son propre niveau de partage');

select is(
  (select count(*)::int from public.profiles
   where id in ('eeeeeeee-0000-0000-0000-000000000005', '99999999-0000-0000-0000-000000000009')),
  1, 'on voit le profil d''un co-membre, pas celui d''un inconnu');

update public.groups set name = 'Détourné' where name = 'Randonnée';
select is(
  (select count(*)::int from public.groups where name = 'Randonnée'),
  1, 'un simple membre ne renomme pas le groupe');

-- Agendas iCal et écritures -------------------------------------------------------
select lives_ok(
  $$select public.add_ics_calendar('Boulot', 'webcal://calendar.example.com/private/abc.ics')$$,
  'un lien webcal est accepté');

select throws_ok(
  $$select public.add_ics_calendar('Clair', 'http://calendar.example.com/a.ics')$$,
  '22023', 'invalid_feed_url', 'un lien en clair est refusé');

select throws_ok(
  $$insert into public.events (calendar_id, title, starts_at, ends_at)
    select id, 'Intrus', now(), now() + interval '1 hour'
    from public.calendars where name = 'Boulot'$$,
  '42501', null, 'personne n''écrit dans un agenda iCal, seul le worker le remplit');

select lives_ok(
  $$insert into public.events (calendar_id, title, starts_at, ends_at)
    select c.id, 'Pique-nique', now(), now() + interval '2 hours'
    from public.calendars c join public.groups g on g.id = c.group_id
    where g.name = 'Randonnée'$$,
  'un membre ajoute un rdv à l''agenda du groupe');

-- Vérifications côté serveur --------------------------------------------------------
reset role;
select is(
  (select f.url from private.calendar_feeds f join public.calendars c on c.id = f.calendar_id
   where c.name = 'Boulot'),
  'https://calendar.example.com/private/abc.ics', 'webcal:// est enregistré en https://');

insert into public.events (calendar_id, source_uid, title, starts_at, ends_at)
select id, 'uid-1@example.com', 'Import', now(), now() from public.calendars where name = 'Boulot';
select throws_ok(
  $$insert into public.events (calendar_id, source_uid, title, starts_at, ends_at)
    select id, 'uid-1@example.com', 'Doublon', now(), now() from public.calendars where name = 'Boulot'$$,
  '23505', null, 'un même UID iCal ne s''importe qu''une fois par agenda');

select * from finish();
rollback;

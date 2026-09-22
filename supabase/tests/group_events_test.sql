-- Rdv de groupe : tout membre en propose, le créateur et les admins les
-- modifient ; chacun répond présent / peut-être / absent, par occurrence
-- pour une série ; les réponses restent entre membres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

insert into auth.users (id, email, raw_user_meta_data) values
  ('6e000000-0000-0000-0000-000000000001', 'gael@test.local', '{"display_name":"Gaël"}'),
  ('6e000000-0000-0000-0000-000000000002', 'hana@test.local', '{"display_name":"Hana"}'),
  ('6e000000-0000-0000-0000-000000000003', 'ivan@test.local', '{"display_name":"Ivan"}'),
  ('6e000000-0000-0000-0000-000000000004', 'jade@test.local', '{"display_name":"Jade"}');

-- Gaël crée le groupe (propriétaire) ; Hana et Ivan le rejoignent ; Jade n'en est pas.
set local role authenticated;
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000001","role":"authenticated"}';
select set_config('agora_test.group', public.create_group('Foot')::text, true);
select set_config('agora_test.code', public.create_invite(current_setting('agora_test.group')::uuid), true);
select set_config('agora_test.cal',
  (select id::text from public.calendars where group_id = current_setting('agora_test.group')::uuid), true);
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000002","role":"authenticated"}';
select public.join_group(current_setting('agora_test.code'), 'busy');
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000003","role":"authenticated"}';
select public.join_group(current_setting('agora_test.code'), 'busy');

-- Proposer ----------------------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000002","role":"authenticated"}';
select lives_ok($$
  insert into public.events (calendar_id, title, starts_at, ends_at, timezone)
  values (current_setting('agora_test.cal')::uuid, 'Match', '2026-10-10 14:00+00', '2026-10-10 16:00+00', 'Europe/Paris')$$,
  'un simple membre propose un rdv au groupe');
select set_config('agora_test.match',
  (select id::text from public.events where title = 'Match'), true);

set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000004","role":"authenticated"}';
select throws_ok($$
  insert into public.events (calendar_id, title, starts_at, ends_at)
  values (current_setting('agora_test.cal')::uuid, 'Intrus', '2026-10-10 14:00+00', '2026-10-10 15:00+00')$$,
  '42501', null, 'qui n''est pas du groupe n''y propose rien');

-- Modifier : le créateur et les admins, pas les autres ------------------------------------------------
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000003","role":"authenticated"}';
update public.events set title = 'Piraté' where id = current_setting('agora_test.match')::uuid;
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000002","role":"authenticated"}';
select is((select title from public.events where id = current_setting('agora_test.match')::uuid), 'Match',
  'un autre membre ne modifie pas le rdv proposé par Hana');
update public.events set location = 'Stade' where id = current_setting('agora_test.match')::uuid;
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000001","role":"authenticated"}';
update public.events set title = 'Match amical' where id = current_setting('agora_test.match')::uuid;
select ok((select title = 'Match amical' and location = 'Stade' from public.events
           where id = current_setting('agora_test.match')::uuid),
  'la créatrice et le propriétaire du groupe le modifient');

-- Répondre à un rdv ponctuel -------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000002","role":"authenticated"}';
select lives_ok($$select public.respond_to_event(current_setting('agora_test.match')::uuid, null, 'yes')$$,
  'Hana répond présente');
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000003","role":"authenticated"}';
select lives_ok($$select public.respond_to_event(current_setting('agora_test.match')::uuid, null, 'maybe')$$,
  'Ivan répond peut-être');
select lives_ok($$select public.respond_to_event(current_setting('agora_test.match')::uuid, null, 'no')$$,
  'puis change d''avis');
select is(
  (select array_agg(status::text order by user_id) from public.event_responses
   where event_id = current_setting('agora_test.match')::uuid),
  array['yes', 'no'], 'une seule réponse par personne, la dernière');
select throws_ok($$select public.respond_to_event(current_setting('agora_test.match')::uuid,
  '2026-10-10 14:00+00', 'yes')$$, '22023', 'invalid_occurrence',
  'un rdv ponctuel se répond sans créneau');

set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000004","role":"authenticated"}';
select throws_ok($$select public.respond_to_event(current_setting('agora_test.match')::uuid, null, 'yes')$$,
  'P0002', 'event_not_found', 'qui n''est pas du groupe ne répond pas');
select is((select count(*)::int from public.event_responses), 0,
  'et ne voit aucune réponse');

-- Un rdv personnel ne se répond pas ---------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000003","role":"authenticated"}';
insert into public.events (calendar_id, title, starts_at, ends_at)
select c.id, 'Dentiste', '2026-10-09 08:00+00', '2026-10-09 09:00+00'
from public.calendars c where c.owner_id = '6e000000-0000-0000-0000-000000000003';
select throws_ok($$select public.respond_to_event(
  (select id from public.events where title = 'Dentiste'), null, 'yes')$$,
  'P0002', 'event_not_found', 'on ne répond qu''aux rdv d''un groupe');

-- Retirer sa réponse ------------------------------------------------------------------------------------
select lives_ok($$select public.respond_to_event(current_setting('agora_test.match')::uuid, null, null)$$,
  'Ivan retire sa réponse');
select is((select count(*)::int from public.event_responses
           where user_id = '6e000000-0000-0000-0000-000000000003'), 0, 'il n''en a plus');

-- Une série : une réponse par occurrence ---------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000001","role":"authenticated"}';
insert into public.events (calendar_id, title, starts_at, ends_at, timezone, rrule)
values (current_setting('agora_test.cal')::uuid, 'Entraînement', '2026-10-06 16:00+00',
        '2026-10-06 17:30+00', 'Europe/Paris', 'FREQ=WEEKLY');
select set_config('agora_test.training',
  (select id::text from public.events where title = 'Entraînement'), true);
-- Occurrences posées comme le ferait le worker.
reset role;
insert into public.event_occurrences (event_id, starts_at, ends_at)
select current_setting('agora_test.training')::uuid, s, s + interval '90 minutes'
from unnest(array['2026-10-06 16:00+00', '2026-10-13 16:00+00', '2026-10-20 16:00+00']::timestamptz[]) s;
set local role authenticated;

set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000002","role":"authenticated"}';
select lives_ok($$select public.respond_to_event(current_setting('agora_test.training')::uuid,
  '2026-10-13 16:00+00', 'yes')$$, 'Hana répond pour l''entraînement du 13');
select throws_ok($$select public.respond_to_event(current_setting('agora_test.training')::uuid, null, 'yes')$$,
  '22023', 'invalid_occurrence', 'une série se répond occurrence par occurrence');
select throws_ok($$select public.respond_to_event(current_setting('agora_test.training')::uuid,
  '2026-10-14 16:00+00', 'yes')$$, '22023', 'invalid_occurrence',
  'un créneau qui n''est pas une occurrence est refusé');
select public.respond_to_event(current_setting('agora_test.training')::uuid, '2026-10-20 16:00+00', 'no');

-- Ma réponse revient avec mon agenda.
select is(
  (select array_agg(my_response::text order by starts_at) from public.my_agenda('2026-10-05', '2026-10-25')
   where calendar_id = current_setting('agora_test.cal')::uuid),
  array[null, 'yes', 'yes', 'no']::text[],
  'my_agenda rend ma réponse : le match, puis occurrence par occurrence');

-- Une occurrence modifiée garde ses réponses -------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000001","role":"authenticated"}';
select public.replace_occurrence(current_setting('agora_test.training')::uuid, '2026-10-13 16:00+00',
  'Entraînement (terrain B)', null, null, '2026-10-13 17:00+00', '2026-10-13 18:30+00', false, null);
select is(
  (select r.status::text from public.event_responses r join public.events e on e.id = r.event_id
   where e.series_id = current_setting('agora_test.training')::uuid and r.occurrence_start is null),
  'yes', 'la réponse de Hana suit l''occurrence devenue un rdv à part');
select public.replace_occurrence(current_setting('agora_test.training')::uuid, '2026-10-13 16:00+00',
  'Entraînement (terrain C)', null, null, '2026-10-13 17:00+00', '2026-10-13 18:30+00', false, null);
select is(
  (select r.status::text from public.event_responses r join public.events e on e.id = r.event_id
   where e.series_id = current_setting('agora_test.training')::uuid and e.title = 'Entraînement (terrain C)'),
  'yes', 'et la suit encore quand l''occurrence est modifiée une seconde fois');

-- Changer l'horaire de la série efface les réponses de ses occurrences --------------------------------------------
update public.events set starts_at = '2026-10-06 17:00+00', ends_at = '2026-10-06 18:30+00'
where id = current_setting('agora_test.training')::uuid;
select is((select count(*)::int from public.event_responses
           where event_id = current_setting('agora_test.training')::uuid), 0,
  'les occurrences ont bougé : leurs réponses ne valent plus');

-- Quitter le groupe efface ses réponses ------------------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"6e000000-0000-0000-0000-000000000002","role":"authenticated"}';
select public.respond_to_event(current_setting('agora_test.match')::uuid, null, 'yes');
delete from public.group_members
where group_id = current_setting('agora_test.group')::uuid and user_id = '6e000000-0000-0000-0000-000000000002';
reset role;
select is((select count(*)::int from public.event_responses
           where user_id = '6e000000-0000-0000-0000-000000000002'), 0,
  'Hana partie, ses réponses partent avec elle');

-- Droits --------------------------------------------------------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.event_responses', 'INSERT')
          and not has_table_privilege('authenticated', 'public.event_responses', 'UPDATE')
          and not has_table_privilege('authenticated', 'public.event_responses', 'DELETE'),
  'une réponse ne s''écrit que par respond_to_event');

select * from finish();
rollback;

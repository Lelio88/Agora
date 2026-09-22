-- Import iCal : le worker prend les flux à relire, applique un flux lu,
-- note un flux inchangé ou un échec. L'URL reste un secret, la visibilité
-- choisie par l'utilisateur survit à chaque relecture.
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

insert into auth.users (id, email, raw_user_meta_data) values
  ('1c500000-0000-0000-0000-000000000001', 'iris@test.local', '{"display_name":"Iris"}'),
  ('1c500000-0000-0000-0000-000000000002', 'hugo@test.local', '{"display_name":"Hugo"}');

set local role authenticated;
set local request.jwt.claims = '{"sub":"1c500000-0000-0000-0000-000000000001","role":"authenticated"}';
select set_config('agora_test.cal',
  public.add_ics_calendar('Boulot', 'webcal://calendar.example.com/private/abc.ics')::text, true);

-- Le secret reste secret ----------------------------------------------------------------------------
select throws_ok($$select url from private.calendar_feeds$$, '42501', null,
  'personne, pas même la propriétaire, ne lit l''URL d''un flux');
select throws_ok($$select * from private.ics_due_feeds(10)$$, '42501', null,
  'un utilisateur n''appelle pas les fonctions du worker');

-- Le worker prend les flux dus ------------------------------------------------------------------------
reset role;
grant usage on schema extensions to agora_worker;
set local role agora_worker;
select is(
  (select url from private.ics_due_feeds(10) where calendar_id = current_setting('agora_test.cal')::uuid),
  'https://calendar.example.com/private/abc.ics', 'un nouveau flux est dû tout de suite, en https');
select is((select count(*)::int from private.ics_due_feeds(10)), 0,
  'un flux pris n''est pas repris aussitôt (bail)');
select throws_ok($$select url from private.calendar_feeds$$, '42501', null,
  'le worker non plus ne lit pas la table des flux');

-- Appliquer un flux lu ---------------------------------------------------------------------------------
select set_config('agora_test.payload', $json$[
  {"uid":"r1@x","recurrence_id":null,"title":"Réunion","description":null,"location":"Salle 2",
   "starts_at":"2026-10-06T08:00:00Z","ends_at":"2026-10-06T09:00:00Z","all_day":false,
   "timezone":"Europe/Paris","rrule":null,"exdates":[]},
  {"uid":"y1@x","recurrence_id":null,"title":"Yoga","description":null,"location":null,
   "starts_at":"2026-10-06T16:00:00Z","ends_at":"2026-10-06T17:00:00Z","all_day":false,
   "timezone":"Europe/Paris","rrule":"FREQ=WEEKLY","exdates":["2026-10-13T16:00:00Z"]},
  {"uid":"y1@x","recurrence_id":"2026-10-20T16:00:00Z","title":"Yoga (décalé)","description":null,
   "location":null,"starts_at":"2026-10-20T18:00:00Z","ends_at":"2026-10-20T19:00:00Z","all_day":false,
   "timezone":"Europe/Paris","rrule":null,"exdates":[]},
  {"uid":"orphan@x","recurrence_id":"2026-10-20T16:00:00Z","title":"Sans série","description":null,
   "location":null,"starts_at":"2026-10-20T18:00:00Z","ends_at":"2026-10-20T19:00:00Z","all_day":false,
   "timezone":"UTC","rrule":null,"exdates":[]}
]$json$, true);
select lives_ok($$select private.ics_apply(current_setting('agora_test.cal')::uuid,
  current_setting('agora_test.payload')::jsonb, '"etag-1"', null)$$,
  'le worker applique un flux lu');

reset role;
select is(
  (select count(*)::int from public.events where calendar_id = current_setting('agora_test.cal')::uuid),
  3, 'un rdv, une série et son occurrence modifiée ; l''occurrence sans série est ignorée');
select ok(
  (select series_id = (select id from public.events where source_uid = 'y1@x' and recurrence_id is null)
   from public.events where source_uid = 'y1@x' and recurrence_id is not null),
  'l''occurrence modifiée est rattachée à sa série');
select ok(
  (select last_synced_at is not null and sync_error is null from public.calendars
   where id = current_setting('agora_test.cal')::uuid),
  'l''agenda affiche une synchro réussie');
select is((select etag from private.calendar_feeds where calendar_id = current_setting('agora_test.cal')::uuid),
  '"etag-1"', 'l''ETag est retenu pour la prochaine relecture');

-- La visibilité choisie survit, un rdv disparu du flux disparaît ---------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"1c500000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok($$select public.set_event_visibility(
  (select id from public.events where source_uid = 'r1@x'), 'busy')$$,
  'Iris masque un rdv importé pour ses groupes');

reset role;
-- ctid (emplacement de la ligne) change à toute réécriture ; updated_at non,
-- now() étant figé dans la transaction du test.
select set_config('agora_test.updated',
  (select ctid::text from public.events where source_uid = 'y1@x' and recurrence_id is null), true);
set local role agora_worker;
select lives_ok($$select private.ics_apply(current_setting('agora_test.cal')::uuid,
  jsonb_set(current_setting('agora_test.payload')::jsonb, '{0,title}', '"Réunion d''équipe"'), '"etag-2"', null)$$,
  'une relecture où la réunion a changé de titre');
reset role;
select ok(
  (select title = 'Réunion d''équipe' and visibility = 'busy' from public.events where source_uid = 'r1@x'),
  'le nouveau titre est pris, la visibilité choisie par Iris reste');
select is(
  (select ctid::text from public.events where source_uid = 'y1@x' and recurrence_id is null),
  current_setting('agora_test.updated'), 'un rdv inchangé n''est pas réécrit');

set local role agora_worker;
select lives_ok($$select private.ics_apply(current_setting('agora_test.cal')::uuid,
  jsonb_set(jsonb_set(current_setting('agora_test.payload')::jsonb - 0,
    '{0,starts_at}', '"2026-10-06T17:00:00Z"'), '{0,ends_at}', '"2026-10-06T18:00:00Z"'), '"etag-3"', null)$$,
  'une relecture sans la réunion, où la série décale son horaire');
reset role;
select is((select count(*)::int from public.events where source_uid = 'r1@x'), 0,
  'un rdv retiré du flux disparaît');
select is(
  (select exdates from public.events where source_uid = 'y1@x' and recurrence_id is null),
  array['2026-10-13T16:00:00Z'::timestamptz],
  'les dates exclues venues du flux restent, même quand l''horaire de la série change');
select is((select count(*)::int from public.events where source_uid = 'y1@x' and recurrence_id is not null), 1,
  'l''occurrence modifiée venue du flux est reposée');

-- Échecs et flux inchangé ------------------------------------------------------------------------------
set local role agora_worker;
select lives_ok($$select private.ics_record_failure(current_setting('agora_test.cal')::uuid, 'unreachable')$$,
  'le worker note un échec');
reset role;
select ok(
  (select c.sync_error = 'unreachable' and f.failure_count = 1 and f.next_sync_at > now()
   from public.calendars c join private.calendar_feeds f on f.calendar_id = c.id
   where c.id = current_setting('agora_test.cal')::uuid),
  'l''erreur s''affiche et la relecture est repoussée');
set local role agora_worker;
select throws_ok($$select private.ics_record_failure(current_setting('agora_test.cal')::uuid, 'Connection refused to 10.0.0.1')$$,
  '22023', 'invalid_sync_error', 'une erreur n''est qu''un code connu : jamais un texte libre');
select lives_ok($$select private.ics_record_unchanged(current_setting('agora_test.cal')::uuid)$$,
  'le worker note un flux inchangé (304)');

-- Synchroniser maintenant -----------------------------------------------------------------------------
set local role authenticated;
set local request.jwt.claims = '{"sub":"1c500000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok($$select public.sync_calendar_now(current_setting('agora_test.cal')::uuid)$$,
  'P0002', 'calendar_not_found', 'Hugo ne relance pas l''agenda d''Iris');
set local request.jwt.claims = '{"sub":"1c500000-0000-0000-0000-000000000001","role":"authenticated"}';
reset role;
update private.calendar_feeds set last_attempt_at = now() - interval '5 minutes'
where calendar_id = current_setting('agora_test.cal')::uuid;
set local role authenticated;
select lives_ok($$select public.sync_calendar_now(current_setting('agora_test.cal')::uuid)$$,
  'Iris demande une relecture immédiate');
reset role;
select ok(
  (select next_sync_at <= now() from private.calendar_feeds
   where calendar_id = current_setting('agora_test.cal')::uuid),
  'le flux redevient dû tout de suite');

select * from finish();
rollback;

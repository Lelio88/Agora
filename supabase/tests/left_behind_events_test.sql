-- Ce qu'une suppression de compte laisse derrière elle : les rdv proposés à
-- un groupe lui appartiennent et lui restent. L'app les annonce avant, et
-- propose de les effacer — d'où ces deux fonctions.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, raw_user_meta_data) values
  ('7e000000-0000-0000-0000-000000000001', 'nina@test.local', '{"display_name":"Nina"}'),
  ('7e000000-0000-0000-0000-000000000002', 'omar@test.local', '{"display_name":"Omar"}'),
  ('7e000000-0000-0000-0000-000000000003', 'perle@test.local', '{"display_name":"Perle"}');

set local role authenticated;

-- Nina possède « Rando » et « Ciné », Omar la rejoint dans « Rando ».
set local request.jwt.claims = '{"sub":"7e000000-0000-0000-0000-000000000001","role":"authenticated"}';
select set_config('agora_test.rando', public.create_group('Rando')::text, true);
select set_config('agora_test.cine', public.create_group('Ciné')::text, true);
select set_config('agora_test.code', public.create_invite(current_setting('agora_test.rando')::uuid), true);
set local request.jwt.claims = '{"sub":"7e000000-0000-0000-0000-000000000002","role":"authenticated"}';
select public.join_group(current_setting('agora_test.code'), 'details');

-- Nina propose deux rdv à « Rando » et un à « Ciné », et garde un rdv perso.
set local request.jwt.claims = '{"sub":"7e000000-0000-0000-0000-000000000001","role":"authenticated"}';
insert into public.events (calendar_id, title, starts_at, ends_at)
select c.id, t.title, t.starts_at, t.starts_at + interval '2 hours'
from (values
  (current_setting('agora_test.rando')::uuid, 'Sortie au lac', '2026-10-10 09:00+00'::timestamptz),
  (current_setting('agora_test.rando')::uuid, 'Sortie en forêt', '2026-10-17 09:00+00'::timestamptz),
  (current_setting('agora_test.cine')::uuid, 'Séance de minuit', '2026-10-12 23:00+00'::timestamptz)
) as t(group_id, title, starts_at)
join public.calendars c on c.group_id = t.group_id;
insert into public.events (calendar_id, title, starts_at, ends_at)
select c.id, 'Dentiste', '2026-10-11 08:00+00', '2026-10-11 09:00+00'
from public.calendars c where c.owner_id = '7e000000-0000-0000-0000-000000000001';

-- Omar propose le sien au même groupe.
set local request.jwt.claims = '{"sub":"7e000000-0000-0000-0000-000000000002","role":"authenticated"}';
insert into public.events (calendar_id, title, starts_at, ends_at)
select c.id, 'Via ferrata', '2026-10-24 09:00+00', '2026-10-24 11:00+00'
from public.calendars c where c.group_id = current_setting('agora_test.rando')::uuid;

-- Ce que Nina laisserait derrière elle ------------------------------------------------
set local request.jwt.claims = '{"sub":"7e000000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select title, group_name from public.my_proposed_group_events() order by starts_at$$,
  $$values ('Sortie au lac'::text, 'Rando'::text),
           ('Séance de minuit'::text, 'Ciné'::text),
           ('Sortie en forêt'::text, 'Rando'::text)$$,
  'Nina voit les trois rdv qu''elle a proposés, avec le nom de leur groupe');
select is(
  (select count(*)::int from public.my_proposed_group_events() where title = 'Dentiste'), 0,
  'son rdv personnel n''y est pas : il part avec le compte');
select is(
  (select count(*)::int from public.my_proposed_group_events() where title = 'Via ferrata'), 0,
  'le rdv proposé par Omar n''est pas le sien');

-- Omar ne voit que le sien -------------------------------------------------------------
set local request.jwt.claims = '{"sub":"7e000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select title from public.my_proposed_group_events()$$,
  $$values ('Via ferrata'::text)$$,
  'chacun ne voit que ce qu''il a proposé');

-- Perle, qui n'est d'aucun groupe ------------------------------------------------------
set local request.jwt.claims = '{"sub":"7e000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is((select count(*)::int from public.my_proposed_group_events()), 0,
  'sans groupe, rien à laisser');

-- Nina efface les siens ------------------------------------------------------------------
set local request.jwt.claims = '{"sub":"7e000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(public.delete_my_proposed_group_events(), 3,
  'la suppression rend le nombre de rdv effacés');
select is((select count(*)::int from public.my_proposed_group_events()), 0,
  'elle ne laisse plus rien derrière elle');
select is(
  (select count(*)::int from public.events e
   join public.calendars c on c.id = e.calendar_id
   where c.owner_id = '7e000000-0000-0000-0000-000000000001'), 1,
  'son agenda personnel est intact');
select is(
  (select count(*)::int from public.events e
   join public.calendars c on c.id = e.calendar_id
   where c.group_id = current_setting('agora_test.rando')::uuid), 1,
  'le rdv d''Omar reste au groupe');

select * from finish();
rollback;

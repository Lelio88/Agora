#!/usr/bin/env bash
# Contrôle de concurrence de delete_my_account(), que pgTAP ne peut pas
# couvrir (une seule session). Le propriétaire A et son héritier B suppriment
# leur compte en même temps ; A est ralenti pour forcer l'entrelacement.
# Attendu : le groupe disparaît. Défaut qu'il garde en respect : le groupe
# survivait avec 0 membre, ni lisible ni supprimable.
#
# Usage (pile locale démarrée) : bash supabase/checks/account_deletion_race.sh
set -euo pipefail

psql_local() { docker exec -i supabase_db_agora psql -U postgres -qtA -v ON_ERROR_STOP=1; }
group='99999999-0000-0000-0000-0000000000c0'
owner='a1a1a1a1-0000-0000-0000-000000000001'
heir='b2b2b2b2-0000-0000-0000-000000000002'

psql_local >/dev/null <<SQL
delete from public.groups where id = '$group';
delete from auth.users where id in ('$owner', '$heir');
insert into auth.users (id, email, raw_user_meta_data) values
  ('$owner', 'owner-a@race.local', '{"display_name":"A"}'),
  ('$heir',  'heir-b@race.local',  '{"display_name":"B"}');
insert into public.groups (id, name) values ('$group', 'Course');
insert into public.group_members (group_id, user_id, role) values
  ('$group', '$owner', 'owner'), ('$group', '$heir', 'admin');
SQL

delete_as() { # $1 : utilisateur, $2 : pause avant commit
  psql_local >/dev/null <<SQL
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$1","role":"authenticated"}';
select public.delete_my_account();
select pg_sleep($2);
commit;
SQL
}

delete_as "$owner" 3 &
sleep 1
delete_as "$heir" 0
wait

left=$(psql_local <<SQL
select count(*) from public.groups where id = '$group';
SQL
)
if [ "$left" != "0" ]; then
  echo "ÉCHEC : le groupe survit aux deux suppressions (course non sérialisée)." >&2
  exit 1
fi
echo "OK : suppressions concurrentes sérialisées, aucun groupe orphelin."

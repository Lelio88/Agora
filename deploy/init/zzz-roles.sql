-- Mots de passe des rôles internes de Supabase, et schéma de Realtime.
--
-- Joué UNE fois, à la création du volume de la base, par l'image
-- supabase/postgres (dossier docker-entrypoint-initdb.d/migrations/, après
-- ses propres migrations, qui créent ces rôles : d'où le préfixe « zzz »).
--
-- Pourquoi : l'image ne propage pas POSTGRES_PASSWORD à ses rôles internes,
-- et son rôle postgres n'est pas superutilisateur — impossible de les
-- toucher une fois le cluster démarré. Changer POSTGRES_PASSWORD après coup
-- n'a donc aucun effet sur eux (voir docs/deployment.md).
--   authenticator        : PostgREST ;
--   supabase_auth_admin  : GoTrue ;
--   supabase_admin       : Realtime (seul rôle porteur de REPLICATION).

\set pgpass `echo "$POSTGRES_PASSWORD"`

alter user authenticator with password :'pgpass';
alter user supabase_auth_admin with password :'pgpass';
alter user supabase_admin with password :'pgpass';

create schema if not exists _realtime;
alter schema _realtime owner to supabase_admin;

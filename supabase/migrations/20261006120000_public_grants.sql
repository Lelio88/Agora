-- =============================================================================
-- Droits du schéma public : event_responses ramenée à la lecture, et les tables
-- futures naissent sans droits.
--
-- La base accorde par défaut TOUS les droits sur une table neuve de public à
-- anon et authenticated (pg_default_acl de Supabase, rôle postgres qui joue les
-- migrations), TRUNCATE compris, qui échappe à la RLS. Le schéma de départ
-- révoquait table par table ; 20260922020000_group_events.sql ne l'a pas fait
-- pour event_responses, qui gardait donc tout pour anon (garde-fou n°2 : rien
-- à anon). La RLS, qui n'ouvre que la lecture aux membres, tenait seule :
-- respond_to_event restait la seule écriture.
--
-- Choix non évident : les droits par défaut des TABLES et SÉQUENCES se ferment
-- ici, pour le seul rôle postgres et le seul schéma public ; ceux des
-- fonctions restent globaux (EXECUTE à PUBLIC est un défaut de Postgres qu'un
-- réglage par schéma ne retire pas) : chaque fonction continue de révoquer
-- elle-même (`revoke execute ... from public, anon`).
--
-- Invariant (supabase/tests/public_grants_test.sql) : rien à anon sur public,
-- ni TRUNCATE, ni TRIGGER, ni REFERENCES à authenticated.
-- =============================================================================

revoke all on public.event_responses from anon, authenticated;
grant select on public.event_responses to authenticated;

alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;

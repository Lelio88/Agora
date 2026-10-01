-- =============================================================================
-- RLS sur les deux tables du bot Discord, comme sur le reste du schéma private.
--
-- Le schéma private n'est pas exposé par PostgREST, mais `authenticated` y a
-- USAGE (les helpers RLS y vivent). Une table sans RLS n'y est protégée que par
-- l'absence de GRANT : un droit ajouté par mégarde suffirait à l'ouvrir. Le RLS
-- sans politique ferme cette porte.
--
-- Sans effet sur le bot : ces tables ne sont lues et écrites que par les
-- fonctions private.discord_* (SECURITY DEFINER), qui appartiennent au même
-- propriétaire que les tables et ne sont donc pas soumises au RLS.
--
-- Invariant (supabase/tests/private_schema_test.sql) : toute table du schéma
-- private a le RLS activé.
-- =============================================================================

alter table private.discord_link_codes enable row level security;
alter table private.discord_reminders_sent enable row level security;

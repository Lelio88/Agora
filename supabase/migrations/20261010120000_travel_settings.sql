-- =============================================================================
-- Domicile : l'adresse de départ par défaut de « Y aller », gardée sur le
-- compte pour suivre la personne d'un appareil à l'autre.
--
-- Choix non évidents :
--   - une table à part, pas une colonne de profiles : un profil se lit par
--     tous les co-membres (nom affiché), un domicile par sa seule personne.
--     Une ligne existe si et seulement si un domicile est posé ; l'effacer,
--     c'est supprimer la ligne ;
--   - l'adresse vient d'une suggestion de la Géoplateforme de l'IGN, choisie
--     dans l'app : son libellé et son point sont gardés ensemble, le point
--     servant au calcul des temps de trajet ;
--   - aucun droit pour agora_worker : ni Discord, ni les assistants IA, ni
--     les vues de groupe ne lisent un domicile ;
--   - les colonnes accordées en INSERT le sont aussi en UPDATE : l'upsert de
--     PostgREST réécrit toutes les colonnes envoyées (ON CONFLICT DO UPDATE).
--
-- Invariants (supabase/tests/travel_settings_test.sql) : lisible et
-- modifiable par sa seule personne, effacé avec le compte.
-- =============================================================================

create table public.travel_settings (
  user_id uuid primary key default auth.uid() references public.profiles (id) on delete cascade,
  home_address text not null
    check (btrim(home_address) <> '' and char_length(home_address) <= 200),
  home_lon double precision not null check (home_lon between -180 and 180),
  home_lat double precision not null check (home_lat between -90 and 90)
);
alter table public.travel_settings enable row level security;

create policy "travel_settings: soi seulement" on public.travel_settings
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.travel_settings from anon, authenticated;
grant select, delete on public.travel_settings to authenticated;
grant insert (home_address, home_lon, home_lat),
  update (home_address, home_lon, home_lat)
  on public.travel_settings to authenticated;

-- =============================================================================
-- Temps de trajet : le mode préféré et l'affichage dans l'agenda, sur le
-- domicile (travel_settings), et le mode choisi pour un rdv
-- (event_travel_modes).
--
-- Choix non évidents :
--   - les durées ne sont jamais stockées : l'app les demande à l'itinéraire
--     de l'IGN et les garde en mémoire. La base ne garde que des choix ;
--   - un choix vise un rdv ou une série entière (son rdv maître) : la RLS
--     n'accepte qu'un rdv que la personne voit, comme calendar_preferences
--     n'accepte qu'un agenda lisible ;
--   - quitter un groupe oublie les choix faits pour ses rdv
--     (private.forget_member_travel_modes), comme ses réponses : ces rdv
--     ne sont plus les siens ;
--   - aucun droit pour agora_worker : ni Discord, ni les assistants IA, ni
--     les créneaux communs ne tiennent compte d'un trajet ;
--   - les colonnes accordées en INSERT le sont aussi en UPDATE : l'upsert
--     de PostgREST réécrit toutes les colonnes envoyées.
--
-- Invariants (supabase/tests/travel_modes_test.sql) : à soi seul, sur un
-- rdv qu'on voit, effacé avec le compte.
-- =============================================================================

alter table public.travel_settings
  add column travel_mode text not null default 'auto'
    check (travel_mode in ('auto', 'car', 'walk')),
  add column show_in_agenda boolean not null default true;
grant insert (travel_mode, show_in_agenda), update (travel_mode, show_in_agenda)
  on public.travel_settings to authenticated;

create table public.event_travel_modes (
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  event_id uuid not null references public.events (id) on delete cascade,
  mode text not null check (mode in ('car', 'walk', 'none')),
  primary key (user_id, event_id)
);
create index event_travel_modes_event_id_idx on public.event_travel_modes (event_id);
alter table public.event_travel_modes enable row level security;

create policy "event_travel_modes: les siens" on public.event_travel_modes
  for select to authenticated using (user_id = (select auth.uid()));
-- La sous-requête passe par la RLS de events : seul un rdv lisible y est.
-- Colonne qualifiée : une homonyme dans events serait lue à sa place.
create policy "event_travel_modes: sur un rdv lisible" on public.event_travel_modes
  for insert to authenticated
  with check (user_id = (select auth.uid())
    and exists (select 1 from public.events e
      where e.id = event_travel_modes.event_id));
create policy "event_travel_modes: modifier les siens" on public.event_travel_modes
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid())
    and exists (select 1 from public.events e
      where e.id = event_travel_modes.event_id));
create policy "event_travel_modes: supprimer les siens" on public.event_travel_modes
  for delete to authenticated using (user_id = (select auth.uid()));

revoke all on public.event_travel_modes from anon, authenticated;
grant select, delete on public.event_travel_modes to authenticated;
grant insert (event_id, mode), update (event_id, mode)
  on public.event_travel_modes to authenticated;

-- Quitter un groupe (ou en être exclu) oublie les modes choisis pour ses rdv.
create function private.forget_member_travel_modes()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from public.event_travel_modes t
  using public.events e, public.calendars c
  where t.user_id = old.user_id and t.event_id = e.id
    and e.calendar_id = c.id and c.group_id = old.group_id;
  return null;
end;
$$;

create trigger group_members_forget_travel_modes
  after delete on public.group_members
  for each row execute function private.forget_member_travel_modes();

revoke execute on function private.forget_member_travel_modes()
  from public, anon, authenticated;

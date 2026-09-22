-- =============================================================================
-- Plusieurs agendas par personne : ranger un rdv dans un autre agenda,
-- supprimer un agenda, préférences d'affichage par personne.
--
-- Choix non évidents :
--   - la suppression passe par delete_calendar() (DELETE direct retiré) :
--     elle refuse le dernier agenda natif, où se créent les nouveaux rdv.
--     Une contrainte ou un trigger bloquerait aussi la cascade de la
--     suppression du compte ; une RPC ne gêne pas cette cascade ;
--   - masquer un agenda dans SA vue est une préférence d'affichage
--     (calendar_preferences), pas de la vie privée : elle ne change rien à ce
--     que voient les groupes (calendars.visibility s'en charge). Une table
--     par personne et par agenda, pour servir aussi aux agendas de groupe ;
--   - déplacer une série emmène ses occurrences modifiées : une exception
--     vit toujours dans l'agenda de sa série (private.check_event_series) ;
--   - seul le CRÉATEUR d'un rdv le change d'agenda. La RLS ne suffit pas :
--     sur la ligne d'arrivée, can_edit_event accepte tout agenda dont on est
--     propriétaire, sans regarder le créateur. Un admin de groupe (qui peut
--     modifier les rdv des autres membres) aurait pu sortir le rdv d'un
--     membre vers son agenda personnel, où le créateur ne le voit plus.
--
-- Invariants : chacun garde au moins un agenda natif ; une préférence ne
-- porte que sur un agenda qu'on peut lire.
-- =============================================================================

-- Ranger un rdv dans un autre agenda : la RLS (can_edit_event, sur la ligne
-- d'avant ET sur la nouvelle) exige un agenda natif où l'on peut écrire.
grant update (calendar_id) on public.events to authenticated;

-- Seul le créateur change un rdv d'agenda (voir l'en-tête). Une occurrence
-- modifiée n'est pas concernée : elle suit sa série (follow_series_calendar,
-- qui peut toucher des occurrences modifiées par d'autres membres). Un
-- écrivain côté serveur (auth.uid() nul) n'est pas soumis à ce contrôle.
create function private.check_event_move()
returns trigger language plpgsql set search_path = '' as $$
begin
  if auth.uid() is not null and new.series_id is null
     and new.calendar_id is distinct from old.calendar_id
     and old.created_by is distinct from auth.uid() then
    raise exception 'event_not_found' using errcode = 'P0002';
  end if;
  return new;
end;
$$;

create trigger events_check_move
  before update of calendar_id on public.events
  for each row execute function private.check_event_move();

create function private.follow_series_calendar()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.events e set calendar_id = new.calendar_id
  where e.series_id = new.id;
  return null;
end;
$$;

create trigger events_follow_series_calendar
  after update of calendar_id on public.events
  for each row
  when (old.calendar_id is distinct from new.calendar_id and new.series_id is null)
  execute function private.follow_series_calendar();

-- -----------------------------------------------------------------------------
-- Suppression d'un agenda
-- -----------------------------------------------------------------------------

drop policy "calendars: supprimer les siens" on public.calendars;
revoke delete on public.calendars from authenticated;

-- Supprime un agenda à soi, avec ses rdv (cascade). Les agendas natifs de
-- la personne sont verrouillés avant de compter : deux suppressions
-- simultanées ne peuvent pas emporter les deux derniers.
create function public.delete_calendar(p_calendar_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  v_calendar public.calendars;
begin
  select * into v_calendar from public.calendars c
  where c.id = p_calendar_id and c.owner_id = auth.uid();
  if not found then
    raise exception 'calendar_not_found' using errcode = 'P0002';
  end if;
  if v_calendar.kind = 'native' then
    perform 1 from public.calendars c
    where c.owner_id = auth.uid() and c.kind = 'native'
    order by c.id
    for update;
    if (select count(*) from public.calendars c
        where c.owner_id = auth.uid() and c.kind = 'native') <= 1 then
      raise exception 'last_native_calendar' using errcode = 'P0001';
    end if;
  end if;
  delete from public.calendars c where c.id = p_calendar_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- Préférences d'affichage, par personne et par agenda
-- -----------------------------------------------------------------------------

create table public.calendar_preferences (
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  calendar_id uuid not null references public.calendars (id) on delete cascade,
  -- Masqué dans la vue de cette personne seulement.
  hidden boolean not null default false,
  primary key (user_id, calendar_id)
);
create index calendar_preferences_calendar_id_idx on public.calendar_preferences (calendar_id);
alter table public.calendar_preferences enable row level security;

create policy "calendar_preferences: les siennes" on public.calendar_preferences
  for select to authenticated using (user_id = (select auth.uid()));
create policy "calendar_preferences: sur un agenda lisible" on public.calendar_preferences
  for insert to authenticated
  with check (user_id = (select auth.uid()) and private.can_read_calendar(calendar_id));
create policy "calendar_preferences: modifier les siennes" on public.calendar_preferences
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and private.can_read_calendar(calendar_id));
create policy "calendar_preferences: supprimer les siennes" on public.calendar_preferences
  for delete to authenticated using (user_id = (select auth.uid()));

revoke all on public.calendar_preferences from anon, authenticated;
grant select, delete on public.calendar_preferences to authenticated;
grant insert (calendar_id, hidden) on public.calendar_preferences to authenticated;
-- calendar_id aussi : l'upsert de PostgREST réécrit toutes les colonnes
-- envoyées (ON CONFLICT DO UPDATE SET calendar_id = excluded.calendar_id…).
-- Sans risque : la RLS garde la ligne sur un agenda lisible, à soi.
grant update (calendar_id, hidden) on public.calendar_preferences to authenticated;

revoke execute on function private.follow_series_calendar(), private.check_event_move()
  from public, anon;
revoke execute on function public.delete_calendar(uuid) from public, anon;
grant execute on function public.delete_calendar(uuid) to authenticated;

-- =============================================================================
-- Agenda perso : séries et exceptions, lecture de l'agenda, contrat avec le
-- worker qui déplie les récurrences.
--
-- Modèle d'une série :
--   - la ligne maîtresse porte la RRULE ; elle ne s'affiche jamais telle
--     quelle, seulement par ses event_occurrences (dépliées par le worker) ;
--   - une occurrence MODIFIÉE est une ligne à part : series_id → la maîtresse,
--     recurrence_id → le créneau d'origine qu'elle remplace ;
--   - une occurrence SUPPRIMÉE est une exception : son créneau d'origine
--     rejoint events.exdates de la maîtresse.
-- Le worker déplie la RRULE en sautant exdates et créneaux remplacés.
--
-- Invariants :
--   - changer l'HORAIRE d'une série (début, fin, règle, fuseau, journée
--     entière) efface ses exceptions : leurs créneaux d'origine ne
--     correspondent plus à rien. Changer son texte les garde ;
--   - l'app ne lit jamais la ligne maîtresse pour afficher l'agenda :
--     my_agenda() renvoie ponctuels, occurrences modifiées et occurrences
--     dépliées ;
--   - le worker agit sous le rôle agora_worker : il lit les colonnes
--     d'horaire des rdv (jamais leur texte), écrit les occurrences et signale
--     chaque série redépliée dans series_expansions, rien d'autre ;
--   - seul qui peut modifier une série peut en remplacer une occurrence.
-- =============================================================================

alter table public.events
  add column series_id uuid references public.events (id) on delete cascade;

alter table public.events
  add constraint events_exception_has_slot check ((series_id is null) = (recurrence_id is null)),
  add constraint events_exception_is_single check (series_id is null or rrule is null);

-- Un créneau d'une série ne se remplace qu'une fois.
create unique index events_series_slot_key on public.events (series_id, recurrence_id)
  where series_id is not null;

grant insert (series_id) on public.events to authenticated;

-- -----------------------------------------------------------------------------
-- Triggers de cohérence des séries (SECURITY DEFINER : une modification déjà
-- autorisée par la RLS doit pouvoir nettoyer les exceptions et occurrences,
-- même celles qu'un autre membre a créées dans un agenda de groupe).
-- -----------------------------------------------------------------------------

-- Verrou d'une série, le temps de la transaction. Contrat partagé avec le
-- worker (lockSeriesQuery, même clé) : il le prend AVANT de relire la série
-- pour la redéplier. Qui efface une occurrence dépliée (remplacement,
-- suppression) le prend aussi ; sinon le worker, ayant lu la série juste
-- avant, réécrirait l'occurrence qu'on vient d'effacer.
create function private.lock_series(p_series_id uuid)
returns void language sql volatile set search_path = '' as $$
  select pg_advisory_xact_lock(hashtextextended(p_series_id::text, 0));
$$;

-- Une exception se rattache à une série existante, du même agenda, que
-- l'appelant a le droit de modifier. Sans ce dernier contrôle, un simple
-- membre d'un agenda de groupe (qui peut y AJOUTER des rdv) rattacherait une
-- « occurrence modifiée » à la série d'un autre membre, et
-- hide_replaced_occurrence effacerait l'occurrence de la victime. Un
-- écrivain côté serveur, sans JWT (auth.uid() nul : synchro iCal, tests),
-- n'est pas soumis à ce contrôle.
create function private.check_event_series()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.series_id is not null and not exists (
    select 1 from public.events m
    where m.id = new.series_id and m.rrule is not null
      and m.series_id is null and m.calendar_id = new.calendar_id
      and (auth.uid() is null or private.can_edit_event(m.calendar_id, m.created_by))
  ) then
    raise exception 'invalid_series' using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger events_check_series
  before insert or update of series_id, recurrence_id, calendar_id on public.events
  for each row execute function private.check_event_series();

-- Changer l'horaire d'une série efface ses exceptions ; une série qui ne se
-- répète plus perd ses occurrences dépliées.
create function private.reset_series_exceptions()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.rrule is null then
    return new;
  end if;
  if new.starts_at is distinct from old.starts_at
     or new.ends_at is distinct from old.ends_at
     or new.rrule is distinct from old.rrule
     or new.timezone is distinct from old.timezone
     or new.all_day is distinct from old.all_day then
    -- Sauf si la mise à jour fournit elle-même ses exceptions (synchro iCal).
    if new.exdates is not distinct from old.exdates then
      new.exdates := '{}';
    end if;
    delete from public.events e where e.series_id = old.id;
  end if;
  if new.rrule is null then
    delete from public.event_occurrences o where o.event_id = old.id;
  end if;
  return new;
end;
$$;

create trigger events_reset_series_exceptions
  before update of starts_at, ends_at, rrule, timezone, all_day on public.events
  for each row execute function private.reset_series_exceptions();

-- Une occurrence modifiée remplace aussitôt l'occurrence dépliée de son
-- créneau, sans attendre le worker : l'agenda n'affiche jamais les deux.
create function private.hide_replaced_occurrence()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform private.lock_series(new.series_id);
  delete from public.event_occurrences o
  where o.event_id = new.series_id and o.starts_at = new.recurrence_id;
  return null;
end;
$$;

create trigger events_hide_replaced_occurrence
  after insert on public.events
  for each row when (new.series_id is not null)
  execute function private.hide_replaced_occurrence();

-- Signale au worker (LISTEN agora_recurrence) la série à redéplier. La charge
-- utile n'est qu'un identifiant : jamais de contenu de rdv dans un canal
-- qu'écoute un service tiers.
create function private.notify_recurrence_change()
returns trigger language plpgsql set search_path = '' as $$
declare
  v_series uuid;
begin
  if tg_op = 'DELETE' then
    v_series := coalesce(old.series_id, case when old.rrule is not null then old.id end);
  else
    v_series := coalesce(
      new.series_id,
      case when new.rrule is not null or (tg_op = 'UPDATE' and old.rrule is not null)
           then new.id end
    );
  end if;
  if v_series is not null then
    perform pg_notify('agora_recurrence', v_series::text);
  end if;
  return null;
end;
$$;

create trigger events_notify_recurrence
  after insert or update or delete on public.events
  for each row execute function private.notify_recurrence_change();

-- -----------------------------------------------------------------------------
-- RPC de l'agenda perso
-- -----------------------------------------------------------------------------

-- Agenda lisible par l'appelant (ses agendas et ceux de ses groupes, par la
-- RLS : SECURITY INVOKER). Chaque ligne est une instance affichable :
--   - rdv ponctuel : series_id et original_start nuls ;
--   - occurrence dépliée : event_id = series_id = la série, original_start =
--     starts_at, rrule = la règle ;
--   - occurrence modifiée : event_id = sa propre ligne, series_id = la série,
--     original_start = le créneau d'origine.
create function public.my_agenda(p_from timestamptz, p_to timestamptz)
returns table (
  event_id uuid,
  series_id uuid,
  original_start timestamptz,
  calendar_id uuid,
  title text,
  location text,
  description text,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day boolean,
  timezone text,
  rrule text,
  visibility public.visibility
)
language plpgsql stable security invoker set search_path = '' as $$
begin
  if p_to <= p_from or p_to - p_from > interval '93 days' then
    raise exception 'invalid_range' using errcode = '22023';
  end if;
  return query
    select e.id, e.series_id, e.recurrence_id, e.calendar_id, e.title, e.location,
           e.description, e.starts_at, e.ends_at, e.all_day, e.timezone, e.rrule, e.visibility
    from public.events e
    where e.rrule is null
      and e.starts_at < p_to and (e.ends_at > p_from or e.starts_at >= p_from)
    union all
    select e.id, e.id, o.starts_at, e.calendar_id, e.title, e.location,
           e.description, o.starts_at, o.ends_at, e.all_day, e.timezone, e.rrule, e.visibility
    from public.event_occurrences o
    join public.events e on e.id = o.event_id
    where o.starts_at < p_to and (o.ends_at > p_from or o.starts_at >= p_from)
    order by 8;
end;
$$;

-- Supprime une seule occurrence d'une série : son créneau devient une
-- exception, une éventuelle occurrence modifiée à ce créneau disparaît, et
-- l'occurrence dépliée s'efface sans attendre le worker.
create function public.delete_occurrence(p_series_id uuid, p_original_start timestamptz)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  v_series public.events;
begin
  perform private.lock_series(p_series_id);
  select * into v_series from public.events e
  where e.id = p_series_id and e.rrule is not null;
  if not found or not private.can_edit_event(v_series.calendar_id, v_series.created_by) then
    raise exception 'event_not_found' using errcode = 'P0002';
  end if;
  delete from public.events e
  where e.series_id = p_series_id and e.recurrence_id = p_original_start;
  update public.events e
  set exdates = array_append(e.exdates, p_original_start)
  where e.id = p_series_id and not (p_original_start = any (e.exdates));
  delete from public.event_occurrences o
  where o.event_id = p_series_id and o.starts_at = p_original_start;
end;
$$;

revoke execute on function private.check_event_series(), private.reset_series_exceptions(),
  private.hide_replaced_occurrence(), private.notify_recurrence_change()
  from public, anon;
-- Appelée seulement depuis des fonctions SECURITY DEFINER.
revoke execute on function private.lock_series(uuid) from public, anon, authenticated;
revoke execute on function public.my_agenda(timestamptz, timestamptz),
  public.delete_occurrence(uuid, timestamptz) from public, anon;
grant execute on function public.my_agenda(timestamptz, timestamptz),
  public.delete_occurrence(uuid, timestamptz) to authenticated;

-- -----------------------------------------------------------------------------
-- Temps réel. L'app relit l'agenda quand un rdv change (events) ou quand le
-- worker a fini de redéplier une série (series_expansions).
--
-- Piège : Realtime n'applique PAS la RLS aux suppressions (Postgres ne peut
-- plus vérifier l'accès à une ligne effacée). Un DELETE part vers TOUS les
-- abonnés de la table, avec la clé primaire de la ligne. D'où :
--   - event_occurrences n'est jamais publiée : sa clé (event_id, starts_at)
--     porte l'horaire, et le worker efface puis réécrit les occurrences à
--     chaque dépliage — tous les abonnés verraient l'horaire des séries de
--     tout le monde, rdv invisibles compris ;
--   - jamais de REPLICA IDENTITY FULL sur une table publiée : les DELETE
--     emporteraient la ligne entière (titres, lieux) ;
--   - events et series_expansions ne diffusent, en suppression, qu'un
--     identifiant opaque.
-- -----------------------------------------------------------------------------

-- Une ligne par série dépliée ; le worker l'écrit quand les occurrences
-- ont réellement changé. Sert de signal temps réel filtré par la RLS.
create table public.series_expansions (
  series_id uuid primary key references public.events (id) on delete cascade,
  expanded_at timestamptz not null default now()
);
alter table public.series_expansions enable row level security;

create policy "series_expansions: lisibles si la série l'est" on public.series_expansions
  for select to authenticated
  -- Colonne qualifiée : nue, series_id désignerait events.series_id.
  using (exists (
    select 1 from public.events e
    where e.id = series_expansions.series_id and private.can_read_calendar(e.calendar_id)
  ));

revoke all on public.series_expansions from anon, authenticated;
grant select on public.series_expansions to authenticated;

alter publication supabase_realtime add table public.events, public.series_expansions;

-- -----------------------------------------------------------------------------
-- Rôle du worker. Sans mot de passe ici : il est posé au déploiement (et par
-- supabase/seed.sql en local). Les rôles vivent hors de la base : on ne le
-- crée qu'une fois.
-- -----------------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'agora_worker') then
    create role agora_worker nologin;
  end if;
end;
$$;

-- Permet à postgres (et aux tests pgTAP) d'endosser le rôle pour le vérifier.
grant agora_worker to postgres;

grant usage on schema public to agora_worker;
-- Seulement ce que le dépliage lit : jamais les titres, lieux ni descriptions.
grant select (id, calendar_id, series_id, recurrence_id, starts_at, ends_at,
  all_day, timezone, rrule, exdates) on public.events to agora_worker;
grant select, insert, delete on public.event_occurrences to agora_worker;
grant select, insert, update on public.series_expansions to agora_worker;

create policy "events: le worker lit tout" on public.events
  for select to agora_worker using (true);
create policy "event_occurrences: le worker les gère" on public.event_occurrences
  for all to agora_worker using (true) with check (true);
create policy "series_expansions: le worker les signale" on public.series_expansions
  for all to agora_worker using (true) with check (true);

-- =============================================================================
-- Agora — schéma de base : profils, groupes, invitations, agendas, rdv, et la
-- règle de visibilité qui décide ce qu'un membre voit des rdv des autres.
--
-- Règle de visibilité (cœur métier) : pour un rdv personnel vu depuis un
-- groupe, le niveau effectif est le PLUS RESTRICTIF de
--   1. group_members.share_level  (réglage du membre pour ce groupe)
--   2. calendars.visibility       (réglage de l'agenda ; null = hérite)
--   3. events.visibility          (réglage du rdv ; null = hérite)
-- avec l'ordre details < busy < invisible, d'où un simple greatest().
--   details   : titre et lieu visibles
--   busy      : créneau « occupé », sans titre ni identifiant
--   invisible : le rdv n'existe pas pour les autres (/dispo le croit libre)
-- Le propriétaire voit toujours ses propres rdv en détail. Les rdv d'un agenda
-- de groupe sont en détail pour tous les membres.
--
-- Invariants :
--   - le détail d'un rdv personnel ne sort de la base, pour un autre que son
--     propriétaire, QUE par private.resolve_group_agenda : les tables events
--     et event_occurrences ne sont lisibles en direct que par le propriétaire
--     (ou les membres pour un agenda de groupe) ;
--   - l'URL d'un flux iCal est un secret (qui la détient lit l'agenda) : elle
--     vit dans private.calendar_feeds, qu'aucun rôle client ne peut lire ;
--   - les tables publiques sont fermées à anon et ouvertes à authenticated
--     colonne par colonne, jamais par défaut.
-- =============================================================================

create schema if not exists private;
revoke all on schema private from public;
-- Les politiques RLS appellent les helpers de private avec les droits du
-- client : il lui faut USAGE sur le schéma (sans aucun droit sur ses tables).
grant usage on schema private to authenticated, service_role;

create type public.visibility as enum ('details', 'busy', 'invisible');
create type public.group_role as enum ('owner', 'admin', 'member');
create type public.calendar_kind as enum ('native', 'ics');

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 60),
  avatar_url text check (char_length(avatar_url) <= 2048),
  -- Fuseau IANA : sert à afficher les heures et à déplier les récurrences.
  timezone text not null default 'Europe/Paris'
    check (timezone ~ '^[A-Za-z]+(/[A-Za-z0-9_+-]+){0,2}$'),
  locale text not null default 'fr' check (locale in ('fr', 'en')),
  created_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  description text check (char_length(description) <= 500),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.group_role not null default 'member',
  -- Prudent par défaut : on rejoint un groupe en ne montrant que « occupé ».
  share_level public.visibility not null default 'busy',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user_id_idx on public.group_members (user_id);

create table public.group_invites (
  code text primary key,
  group_id uuid not null references public.groups (id) on delete cascade,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  expires_at timestamptz not null default now() + interval '7 days',
  max_uses integer check (max_uses > 0),
  uses integer not null default 0 check (uses >= 0),
  created_at timestamptz not null default now()
);
create index group_invites_group_id_idx on public.group_invites (group_id);

-- Un agenda appartient à une personne OU à un groupe.
create table public.calendars (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid default auth.uid() references public.profiles (id) on delete cascade,
  group_id uuid references public.groups (id) on delete cascade,
  kind public.calendar_kind not null default 'native',
  name text not null check (char_length(name) between 1 and 60),
  color text check (color ~ '^#[0-9A-Fa-f]{6}$'),
  -- null = hérite du réglage de groupe ; ne peut que restreindre.
  visibility public.visibility check (visibility is distinct from 'details'),
  -- État de synchro d'un agenda iCal, écrit par le worker, lu par le proprio.
  last_synced_at timestamptz,
  sync_error text,
  created_at timestamptz not null default now(),
  constraint calendars_single_owner check (num_nonnulls(owner_id, group_id) = 1),
  constraint calendars_group_is_native check (group_id is null or kind = 'native'),
  constraint calendars_group_has_no_privacy check (group_id is null or visibility is null)
);
create index calendars_owner_id_idx on public.calendars (owner_id);
create index calendars_group_id_idx on public.calendars (group_id);

-- Secret : l'URL iCal donne accès à tout l'agenda d'origine.
create table private.calendar_feeds (
  calendar_id uuid primary key references public.calendars (id) on delete cascade,
  url text not null check (url ~ '^https://' and char_length(url) <= 2048),
  etag text,
  last_modified text,
  failure_count integer not null default 0
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  calendar_id uuid not null references public.calendars (id) on delete cascade,
  -- UID iCal (+ RECURRENCE-ID pour une occurrence modifiée) ; null si natif.
  source_uid text,
  recurrence_id timestamptz,
  title text not null check (char_length(title) between 1 and 200),
  description text check (char_length(description) <= 5000),
  location text check (char_length(location) <= 300),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  all_day boolean not null default false,
  timezone text not null default 'Europe/Paris'
    check (timezone ~ '^[A-Za-z]+(/[A-Za-z0-9_+-]+){0,2}$'),
  -- RRULE RFC 5545 sans le préfixe « RRULE: ». Pas de fréquence infra-
  -- journalière : son dépliage exploserait le nombre d'occurrences.
  rrule text check (
    char_length(rrule) <= 500
    and rrule ~ '(^|;)FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)(;|$)'
  ),
  exdates timestamptz[] not null default '{}',
  -- null = hérite ; ne peut que restreindre. Jamais écrasé par la synchro.
  visibility public.visibility check (visibility is distinct from 'details'),
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint events_chronological check (ends_at >= starts_at)
);
create index events_calendar_starts_idx on public.events (calendar_id, starts_at);
-- Clé de synchro iCal : partielle, sinon tous les rdv natifs (source_uid
-- null) entreraient en collision. NULLS NOT DISTINCT pour que l'occurrence
-- « maîtresse » (recurrence_id null) reste unique elle aussi.
create unique index events_source_key on public.events (calendar_id, source_uid, recurrence_id)
  nulls not distinct where source_uid is not null;

-- Occurrences dépliées des rdv récurrents, sur une fenêtre glissante.
-- Écrites par le worker seul (unique implémentation des RRULE) ; un rdv
-- ponctuel n'y figure pas, il se lit directement dans events.
create table public.event_occurrences (
  event_id uuid not null references public.events (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  primary key (event_id, starts_at),
  constraint event_occurrences_chronological check (ends_at >= starts_at)
);
create index event_occurrences_starts_idx on public.event_occurrences (starts_at);

-- -----------------------------------------------------------------------------
-- Helpers (schéma private, non exposé par l'API). SECURITY DEFINER pour que
-- les politiques de group_members puissent interroger group_members sans
-- récursion RLS.
-- -----------------------------------------------------------------------------

create function private.is_group_member(p_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id and gm.user_id = auth.uid()
  );
$$;

create function private.is_group_admin(p_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id and gm.user_id = auth.uid()
      and gm.role in ('owner', 'admin')
  );
$$;

create function private.is_group_owner(p_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id and gm.user_id = auth.uid() and gm.role = 'owner'
  );
$$;

create function private.shares_group_with(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.group_members mine
    join public.group_members theirs on theirs.group_id = mine.group_id
    where mine.user_id = auth.uid() and theirs.user_id = p_user_id
  );
$$;

create function private.can_read_calendar(p_calendar_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.calendars c
    where c.id = p_calendar_id
      and (c.owner_id = auth.uid()
           or (c.group_id is not null and private.is_group_member(c.group_id)))
  );
$$;

-- Créer un rdv : agenda natif à soi, ou agenda de groupe dont on est membre.
-- Un agenda iCal n'accepte que les écritures du worker.
create function private.can_add_event(p_calendar_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.calendars c
    where c.id = p_calendar_id and c.kind = 'native'
      and (c.owner_id = auth.uid()
           or (c.group_id is not null and private.is_group_member(c.group_id)))
  );
$$;

-- Modifier un rdv : le sien, ou dans un agenda de groupe celui qu'on a créé
-- (les admins du groupe peuvent tout modifier).
create function private.can_edit_event(p_calendar_id uuid, p_created_by uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.calendars c
    where c.id = p_calendar_id and c.kind = 'native'
      and (c.owner_id = auth.uid()
           or (c.group_id is not null
               and private.is_group_member(c.group_id)
               and (p_created_by = auth.uid() or private.is_group_admin(c.group_id))))
  );
$$;

create function private.random_invite_code()
returns text language sql volatile set search_path = '' as $$
  -- 8 caractères sur un alphabet de 32 sans ambiguïté (ni 0/O, ni 1/I) :
  -- 32^8 ≈ 10^12 codes, et 256 étant multiple de 32, le tirage est uniforme.
  select string_agg(
    substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + get_byte(b.bytes, i) % 32, 1),
    ''
  )
  from (select extensions.gen_random_bytes(8) as bytes) b,
       generate_series(0, 7) as i;
$$;

create function private.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger events_touch_updated_at
  before update on public.events
  for each row execute function private.touch_updated_at();

-- Profil + agenda par défaut à l'inscription, quel que soit le fournisseur
-- (e-mail, Google, Discord). Le nom vient des métadonnées ; jamais de
-- l'adresse e-mail, que les autres membres n'ont pas à connaître.
create function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    left(coalesce(
      nullif(btrim(meta ->> 'display_name'), ''),
      nullif(btrim(meta ->> 'full_name'), ''),
      nullif(btrim(meta -> 'custom_claims' ->> 'global_name'), ''),
      nullif(btrim(meta ->> 'name'), ''),
      'Membre'
    ), 60),
    nullif(meta ->> 'avatar_url', '')
  );
  insert into public.calendars (owner_id, name) values (new.id, 'Agenda');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- -----------------------------------------------------------------------------
-- Résolution de l'agenda d'un groupe — SEUL chemin par lequel le détail d'un
-- rdv personnel atteint quelqu'un d'autre que son propriétaire.
--   p_viewer       : qui regarde (null pour une publication Discord) ;
--   p_personal_cap : plafond appliqué aux rdv personnels — 'details' dans
--                    l'app, 'busy' pour un salon Discord, dont l'audience
--                    déborde du groupe.
-- -----------------------------------------------------------------------------

create function private.resolve_group_agenda(
  p_group_id uuid,
  p_viewer uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_personal_cap public.visibility
)
returns table (
  event_id uuid,
  user_id uuid,
  is_group_event boolean,
  level public.visibility,
  title text,
  location text,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day boolean
)
language sql stable security definer set search_path = '' as $$
  with personal as (
    select e.id, c.owner_id, false as is_group_event, e.title, e.location,
           e.starts_at, e.ends_at, e.all_day, e.rrule,
           case
             when c.owner_id = p_viewer then 'details'::public.visibility
             else greatest(
               gm.share_level,
               coalesce(c.visibility, 'details'),
               coalesce(e.visibility, 'details'),
               p_personal_cap
             )
           end as level
    from public.group_members gm
    join public.calendars c on c.owner_id = gm.user_id
    join public.events e on e.calendar_id = c.id
    where gm.group_id = p_group_id
  ),
  shared as (
    select e.id, null::uuid, true, e.title, e.location,
           e.starts_at, e.ends_at, e.all_day, e.rrule,
           'details'::public.visibility
    from public.calendars c
    join public.events e on e.calendar_id = c.id
    where c.group_id = p_group_id
  ),
  candidates as (
    select * from personal
    union all
    select * from shared
  ),
  instances as (
    select cd.id, cd.owner_id, cd.is_group_event, cd.level, cd.title,
           cd.location, cd.starts_at, cd.ends_at, cd.all_day
    from candidates cd
    where cd.rrule is null
    union all
    select cd.id, cd.owner_id, cd.is_group_event, cd.level, cd.title,
           cd.location, o.starts_at, o.ends_at, cd.all_day
    from candidates cd
    join public.event_occurrences o on o.event_id = cd.id
    where cd.rrule is not null
  )
  select
    case when i.level = 'details' then i.id end,
    i.owner_id,
    i.is_group_event,
    i.level,
    case when i.level = 'details' then i.title end,
    case when i.level = 'details' then i.location end,
    i.starts_at,
    i.ends_at,
    i.all_day
  from instances i
  where i.level <> 'invisible'
    and i.starts_at < p_to
    -- chevauchement de [from, to[, rdv de durée nulle compris
    and (i.ends_at > p_from or i.starts_at >= p_from)
  order by i.starts_at, i.owner_id nulls first;
$$;

-- -----------------------------------------------------------------------------
-- RPC exposées à l'app
-- -----------------------------------------------------------------------------

-- Plus longue plage qu'une requête d'agenda peut couvrir (un trimestre).
create function public.group_agenda(p_group_id uuid, p_from timestamptz, p_to timestamptz)
returns table (
  event_id uuid,
  user_id uuid,
  is_group_event boolean,
  level public.visibility,
  title text,
  location text,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day boolean
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_group_member(p_group_id) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;
  if p_to <= p_from or p_to - p_from > interval '93 days' then
    raise exception 'invalid_range' using errcode = '22023';
  end if;
  return query
    select * from private.resolve_group_agenda(
      p_group_id, auth.uid(), p_from, p_to, 'details'
    );
end;
$$;

-- Crée le groupe, son agenda partagé, et en fait propriétaire l'appelant.
create function public.create_group(p_name text, p_description text default null)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_group_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  insert into public.groups (name, description, created_by)
  values (btrim(p_name), nullif(btrim(p_description), ''), auth.uid())
  returning id into v_group_id;
  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, auth.uid(), 'owner');
  insert into public.calendars (owner_id, group_id, name)
  values (null, v_group_id, btrim(p_name));
  return v_group_id;
end;
$$;

-- Crée une invitation ; tout membre peut inviter.
create function public.create_invite(
  p_group_id uuid,
  p_valid_for interval default interval '7 days',
  p_max_uses integer default null
)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_code text;
begin
  if not private.is_group_member(p_group_id) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;
  if p_valid_for <= interval '0' or p_valid_for > interval '30 days' then
    raise exception 'invalid_validity' using errcode = '22023';
  end if;
  insert into public.group_invites (code, group_id, expires_at, max_uses)
  values (private.random_invite_code(), p_group_id, now() + p_valid_for, p_max_uses)
  returning code into v_code;
  return v_code;
end;
$$;

-- Rejoint un groupe par code. Un code inconnu, expiré ou épuisé produit la
-- même erreur, pour ne rien révéler de l'existence d'un code.
create function public.join_group(p_code text)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_invite public.group_invites;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  select * into v_invite
  from public.group_invites gi
  where gi.code = upper(btrim(p_code))
  for update;
  if not found
     or v_invite.expires_at <= now()
     or (v_invite.max_uses is not null and v_invite.uses >= v_invite.max_uses) then
    raise exception 'invite_invalid' using errcode = 'P0002';
  end if;
  if private.is_group_member(v_invite.group_id) then
    return v_invite.group_id;
  end if;
  insert into public.group_members (group_id, user_id) values (v_invite.group_id, auth.uid());
  update public.group_invites gi set uses = gi.uses + 1 where gi.code = v_invite.code;
  return v_invite.group_id;
end;
$$;

-- Nombre maximal d'agendas iCal par personne : borne la charge du worker.
create function public.add_ics_calendar(p_name text, p_url text, p_color text default null)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_url text := btrim(p_url);
  v_calendar_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  -- webcal:// est le même flux servi en https.
  if v_url ~* '^webcal://' then
    v_url := 'https://' || substr(v_url, 10);
  end if;
  if v_url !~* '^https://[^/\s@]+(/\S*)?$' or char_length(v_url) > 2048 then
    raise exception 'invalid_feed_url' using errcode = '22023';
  end if;
  if (select count(*) from public.calendars c
      where c.owner_id = auth.uid() and c.kind = 'ics') >= 10 then
    raise exception 'too_many_feeds' using errcode = '54000';
  end if;
  insert into public.calendars (owner_id, kind, name, color)
  values (auth.uid(), 'ics', btrim(p_name), p_color)
  returning id into v_calendar_id;
  insert into private.calendar_feeds (calendar_id, url) values (v_calendar_id, v_url);
  return v_calendar_id;
end;
$$;

-- Masque ou démasque un de ses rdv, iCal compris (la synchro ne touche
-- jamais à cette colonne). null = hérite du réglage de l'agenda et du groupe.
create function public.set_event_visibility(p_event_id uuid, p_visibility public.visibility)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if p_visibility = 'details' then
    raise exception 'visibility_can_only_restrict' using errcode = '22023';
  end if;
  update public.events e
  set visibility = p_visibility
  from public.calendars c
  where e.id = p_event_id and c.id = e.calendar_id and c.owner_id = auth.uid();
  if not found then
    raise exception 'event_not_found' using errcode = 'P0002';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Droits : tout fermer, puis ouvrir au plus juste.
-- -----------------------------------------------------------------------------

revoke all on public.profiles, public.groups, public.group_members,
  public.group_invites, public.calendars, public.events, public.event_occurrences
  from anon, authenticated;
revoke all on private.calendar_feeds from public, anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, avatar_url, timezone, locale) on public.profiles to authenticated;

grant select, delete on public.groups to authenticated;
grant update (name, description) on public.groups to authenticated;

grant select, delete on public.group_members to authenticated;
-- Le rôle ne se change pas en direct : sinon chacun pourrait se promouvoir.
grant update (share_level) on public.group_members to authenticated;

grant select, delete on public.group_invites to authenticated;

grant select, delete on public.calendars to authenticated;
grant insert (name, color, visibility) on public.calendars to authenticated;
grant update (name, color, visibility) on public.calendars to authenticated;

grant select, delete on public.events to authenticated;
grant insert (calendar_id, recurrence_id, title, description, location, starts_at,
  ends_at, all_day, timezone, rrule, exdates, visibility) on public.events to authenticated;
grant update (recurrence_id, title, description, location, starts_at, ends_at,
  all_day, timezone, rrule, exdates, visibility) on public.events to authenticated;

grant select on public.event_occurrences to authenticated;

grant all on public.profiles, public.groups, public.group_members, public.group_invites,
  public.calendars, public.events, public.event_occurrences to service_role;
grant all on private.calendar_feeds to service_role;

-- Postgres accorde EXECUTE à PUBLIC sur toute nouvelle fonction : on retire.
revoke execute on all functions in schema private from public, anon;
grant execute on function private.is_group_member(uuid), private.is_group_admin(uuid),
  private.is_group_owner(uuid), private.shares_group_with(uuid), private.can_read_calendar(uuid),
  private.can_add_event(uuid), private.can_edit_event(uuid, uuid)
  to authenticated;
grant execute on function private.resolve_group_agenda(uuid, uuid, timestamptz, timestamptz, public.visibility)
  to service_role;

revoke execute on function public.group_agenda(uuid, timestamptz, timestamptz),
  public.create_group(text, text), public.create_invite(uuid, interval, integer),
  public.join_group(text), public.add_ics_calendar(text, text, text),
  public.set_event_visibility(uuid, public.visibility)
  from public, anon;
grant execute on function public.group_agenda(uuid, timestamptz, timestamptz),
  public.create_group(text, text), public.create_invite(uuid, interval, integer),
  public.join_group(text), public.add_ics_calendar(text, text, text),
  public.set_event_visibility(uuid, public.visibility)
  to authenticated;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invites enable row level security;
alter table public.calendars enable row level security;
alter table public.events enable row level security;
alter table public.event_occurrences enable row level security;
alter table private.calendar_feeds enable row level security;

create policy "profiles: soi et les co-membres" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or private.shares_group_with(id));
create policy "profiles: soi seulement" on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "groups: membres" on public.groups
  for select to authenticated using (private.is_group_member(id));
create policy "groups: admins modifient" on public.groups
  for update to authenticated
  using (private.is_group_admin(id)) with check (private.is_group_admin(id));
create policy "groups: le propriétaire supprime" on public.groups
  for delete to authenticated using (private.is_group_owner(id));

create policy "group_members: co-membres" on public.group_members
  for select to authenticated using (private.is_group_member(group_id));
create policy "group_members: son propre réglage" on public.group_members
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- Quitter (sauf le propriétaire, qui doit d'abord transmettre le groupe), ou
-- exclure un simple membre quand on est admin.
create policy "group_members: quitter ou exclure" on public.group_members
  for delete to authenticated
  using (
    (user_id = (select auth.uid()) and role <> 'owner')
    or (role = 'member' and private.is_group_admin(group_id))
  );

create policy "group_invites: membres" on public.group_invites
  for select to authenticated using (private.is_group_member(group_id));
create policy "group_invites: auteur ou admin révoque" on public.group_invites
  for delete to authenticated
  using (created_by = (select auth.uid()) or private.is_group_admin(group_id));

create policy "calendars: les siens et ceux de ses groupes" on public.calendars
  for select to authenticated using (private.can_read_calendar(id));
create policy "calendars: créer un agenda natif à soi" on public.calendars
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and kind = 'native' and group_id is null);
create policy "calendars: modifier les siens ou ceux de ses groupes (admin)" on public.calendars
  for update to authenticated
  using (owner_id = (select auth.uid()) or (group_id is not null and private.is_group_admin(group_id)))
  with check (owner_id = (select auth.uid()) or (group_id is not null and private.is_group_admin(group_id)));
-- Un agenda de groupe disparaît avec son groupe, jamais seul.
create policy "calendars: supprimer les siens" on public.calendars
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy "events: lisibles si l'agenda l'est" on public.events
  for select to authenticated using (private.can_read_calendar(calendar_id));
create policy "events: créer" on public.events
  for insert to authenticated with check (private.can_add_event(calendar_id));
create policy "events: modifier" on public.events
  for update to authenticated
  using (private.can_edit_event(calendar_id, created_by))
  with check (private.can_edit_event(calendar_id, created_by));
create policy "events: supprimer" on public.events
  for delete to authenticated using (private.can_edit_event(calendar_id, created_by));

create policy "event_occurrences: lisibles si le rdv l'est" on public.event_occurrences
  for select to authenticated
  using (exists (
    select 1 from public.events e
    where e.id = event_id and private.can_read_calendar(e.calendar_id)
  ));

-- =============================================================================
-- Proche relié à un membre : l'agenda d'un proche peut désigner le compte
-- d'un co-membre de groupe (`calendars.contact_user_id`). Ana tient l'agenda
-- de Ben, qui est aussi dans sa famille sur Agora : son nom suit celui de
-- Ben, et l'app montre à côté ce que Ben partage dans leurs groupes.
--
-- Choix non évidents :
--   - le lien ne se pose que vers quelqu'un avec qui l'on partage un groupe
--     (`not_a_co_member` sinon) : on ne relie qu'une personne déjà connue,
--     et le lien ne révèle jamais qu'une adresse ou un compte existe ;
--   - il n'appartient qu'au propriétaire de l'agenda : la colonne n'est
--     lisible que par lui (RLS des agendas), et ne s'écrit que par
--     `link_contact` et `create_member_contact` (aucun droit de colonne).
--     Le membre ne sait pas qu'il est le proche de quelqu'un ;
--   - le nom suit le profil du membre (`private.follow_contact_name`) tant
--     qu'ils partagent un groupe : hors de tout groupe commun, Ana ne lirait
--     plus son profil, et son nouveau nom ne lui parvient plus. Le dernier
--     nom reçu reste, comme après un délien ou la suppression du compte du
--     membre (`on delete set null`) ;
--   - un membre n'est le proche que d'un seul agenda de son propriétaire
--     (index unique) : « Ajouter à mes proches » rend le proche existant ;
--   - rien ne change pour la vie privée des rdv : l'agenda d'un proche
--     reste invisible et hors des vues de groupe
--     (20261007120000_contact_calendars.sql), lien ou pas.
--
-- Invariants (supabase/tests/contact_member_test.sql) : lien au seul
-- propriétaire, vers un co-membre, un par membre ; le nom ne suit que
-- dans un groupe commun.
-- =============================================================================

alter table public.calendars
  add column contact_user_id uuid references public.profiles (id) on delete set null;
alter table public.calendars add constraint calendars_contact_user_is_contact
  check (contact_user_id is null or contact);
create unique index calendars_contact_user_once
  on public.calendars (owner_id, contact_user_id)
  where contact_user_id is not null;
-- Le renommage d'un membre et la suppression de son compte cherchent ses
-- proches par lui seul.
create index calendars_contact_user
  on public.calendars (contact_user_id)
  where contact_user_id is not null;

-- Le nom du membre, tant qu'il partage un groupe avec le propriétaire.
create function private.follow_contact_name()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.calendars c
  set name = new.display_name
  where c.contact_user_id = new.id
    and c.name is distinct from new.display_name
    and exists (
      select 1
      from public.group_members owner_side
      join public.group_members member_side
        on member_side.group_id = owner_side.group_id
      where owner_side.user_id = c.owner_id and member_side.user_id = new.id
    );
  return null;
end;
$$;
revoke execute on function private.follow_contact_name() from public, anon, authenticated;

create trigger profiles_follow_contact_name
  after update of display_name on public.profiles
  for each row when (old.display_name is distinct from new.display_name)
  execute function private.follow_contact_name();

-- Relie l'agenda d'un proche au membre p_user_id (null : délie).
create function public.link_contact(p_calendar_id uuid, p_user_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  v_name text;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  perform 1 from public.calendars c
  where c.id = p_calendar_id and c.owner_id = auth.uid() and c.contact
  for update;
  if not found then
    raise exception 'calendar_not_found' using errcode = 'P0002';
  end if;
  if p_user_id is null then
    update public.calendars set contact_user_id = null where id = p_calendar_id;
    return;
  end if;
  if p_user_id = auth.uid() or not private.shares_group_with(p_user_id) then
    raise exception 'not_a_co_member' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.calendars c
             where c.owner_id = auth.uid() and c.contact_user_id = p_user_id
               and c.id <> p_calendar_id) then
    raise exception 'contact_already_linked' using errcode = 'P0001';
  end if;
  select p.display_name into v_name from public.profiles p where p.id = p_user_id;
  begin
    update public.calendars
    set contact_user_id = p_user_id, name = v_name
    where id = p_calendar_id;
  exception when unique_violation then
    -- Un autre proche relié au même membre dans l'intervalle.
    raise exception 'contact_already_linked' using errcode = 'P0001';
  end;
end;
$$;

revoke execute on function public.link_contact(uuid, uuid) from public, anon;
grant execute on function public.link_contact(uuid, uuid) to authenticated;

-- Le proche du membre p_user_id : l'existant, ou un agenda de proche neuf à
-- son nom.
create function public.create_member_contact(p_user_id uuid)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  v_calendar_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_user_id is null or p_user_id = auth.uid()
     or not private.shares_group_with(p_user_id) then
    raise exception 'not_a_co_member' using errcode = 'P0001';
  end if;
  select c.id into v_calendar_id from public.calendars c
  where c.owner_id = auth.uid() and c.contact_user_id = p_user_id;
  if found then
    return v_calendar_id;
  end if;
  begin
    insert into public.calendars (owner_id, kind, name, visibility, contact, contact_user_id)
    select auth.uid(), 'native', p.display_name, 'invisible', true, p_user_id
    from public.profiles p where p.id = p_user_id
    returning id into v_calendar_id;
  exception when unique_violation then
    -- Deux appuis simultanés : l'autre l'a créé, c'est le même proche.
    select c.id into v_calendar_id from public.calendars c
    where c.owner_id = auth.uid() and c.contact_user_id = p_user_id;
  end;
  return v_calendar_id;
end;
$$;

revoke execute on function public.create_member_contact(uuid) from public, anon;
grant execute on function public.create_member_contact(uuid) to authenticated;

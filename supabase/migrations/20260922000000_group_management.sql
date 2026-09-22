-- =============================================================================
-- Gestion d'un groupe : partage choisi à l'arrivée, aperçu d'une invitation,
-- rôles et transmission du groupe.
--
-- Choix non évidents :
--   - join_group prend le niveau de partage choisi par la personne qui
--     rejoint, dans la même transaction : un réglage posé juste après
--     laisserait voir ses créneaux (« occupé » par défaut) à quelqu'un qui
--     voulait ne rien partager ;
--   - invite_preview montre le nom et la taille du groupe à qui détient un
--     code valide (le code est le secret) ; un code inconnu, expiré ou
--     épuisé répond la même erreur, comme join_group ;
--   - le propriétaire seul nomme ou retire des admins et transmet le groupe.
--     Transmettre fait de l'ancien propriétaire un admin, qui peut ensuite
--     quitter le groupe (un propriétaire ne quitte pas, cf. RLS) ;
--   - set_member_role et transfer_group verrouillent la ligne du groupe,
--     comme delete_my_account : une transmission et une suppression de
--     compte simultanées se sérialisent.
--
-- Invariant : un groupe a toujours exactement un propriétaire.
-- =============================================================================

drop function public.join_group(text);

-- Rejoint un groupe par code, avec le niveau de partage choisi. Un code
-- inconnu, expiré ou épuisé produit la même erreur, pour ne rien révéler de
-- l'existence d'un code. Déjà membre : rien ne change (pas même le partage).
create function public.join_group(p_code text, p_share_level public.visibility default 'busy')
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
  insert into public.group_members (group_id, user_id, share_level)
  values (v_invite.group_id, auth.uid(), coalesce(p_share_level, 'busy'));
  update public.group_invites gi set uses = gi.uses + 1 where gi.code = v_invite.code;
  return v_invite.group_id;
end;
$$;

-- Ce qu'une invitation valide laisse voir avant de rejoindre.
create function public.invite_preview(p_code text)
returns table (group_id uuid, name text, member_count integer, is_member boolean)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_invite public.group_invites;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  select * into v_invite from public.group_invites gi where gi.code = upper(btrim(p_code));
  if not found
     or v_invite.expires_at <= now()
     or (v_invite.max_uses is not null and v_invite.uses >= v_invite.max_uses) then
    raise exception 'invite_invalid' using errcode = 'P0002';
  end if;
  return query
    select g.id, g.name,
           (select count(*)::integer from public.group_members gm where gm.group_id = g.id),
           private.is_group_member(g.id)
    from public.groups g
    where g.id = v_invite.group_id;
end;
$$;

-- Nomme un membre admin, ou le repasse simple membre. Propriétaire seul.
create function public.set_member_role(
  p_group_id uuid,
  p_user_id uuid,
  p_role public.group_role
)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  perform 1 from public.groups g where g.id = p_group_id for update;
  if not private.is_group_owner(p_group_id) then
    raise exception 'not_group_owner' using errcode = '42501';
  end if;
  if p_role not in ('admin', 'member') then
    raise exception 'invalid_role' using errcode = '22023';
  end if;
  update public.group_members gm set role = p_role
  where gm.group_id = p_group_id and gm.user_id = p_user_id and gm.role <> 'owner';
  if not found then
    raise exception 'invalid_member' using errcode = '22023';
  end if;
end;
$$;

-- Transmet le groupe à un autre membre ; l'ancien propriétaire devient admin.
create function public.transfer_group(p_group_id uuid, p_new_owner uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  perform 1 from public.groups g where g.id = p_group_id for update;
  if not private.is_group_owner(p_group_id) then
    raise exception 'not_group_owner' using errcode = '42501';
  end if;
  if p_new_owner = auth.uid() or not exists (
    select 1 from public.group_members gm
    where gm.group_id = p_group_id and gm.user_id = p_new_owner
  ) then
    raise exception 'invalid_member' using errcode = '22023';
  end if;
  update public.group_members gm set role = 'admin'
  where gm.group_id = p_group_id and gm.user_id = auth.uid();
  update public.group_members gm set role = 'owner'
  where gm.group_id = p_group_id and gm.user_id = p_new_owner;
end;
$$;

revoke execute on function public.join_group(text, public.visibility),
  public.invite_preview(text),
  public.set_member_role(uuid, uuid, public.group_role),
  public.transfer_group(uuid, uuid)
  from public, anon;
grant execute on function public.join_group(text, public.visibility),
  public.invite_preview(text),
  public.set_member_role(uuid, uuid, public.group_role),
  public.transfer_group(uuid, uuid)
  to authenticated;

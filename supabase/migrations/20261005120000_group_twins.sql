-- =============================================================================
-- Jumelage d'un groupe avec un groupe d'une autre app du conteneur (Arpente).
--
-- Les deux apps ne se parlent pas : elles s'ouvrent l'une l'autre par des liens
-- préremplis (protocole : docs/liens-inter-apps.md du dépôt méta). Un jumeau
-- garde le code qui fait rejoindre le groupe de l'autre app, que ses membres
-- voient (« Rejoindre aussi dans Arpente »), et l'invitation que l'on a donnée
-- à l'autre app pour qu'on rejoigne celui-ci.
--
-- Choix non évidents :
--   - l'invitation du jumeau est une invitation ordinaire SANS échéance
--     (expires_at nul) : elle passe par join_group, donc par le choix du
--     partage. Les invitations de la fenêtre « Inviter » gardent leurs 7 jours
--     (le défaut de la colonne ne change pas, create_invite refuse toujours
--     plus de 30 jours) ;
--   - join_group et invite_preview sont redéfinies pour dire l'échéance nulle
--     en clair : « expires_at <= now() » vaut NULL, qu'un IF lit comme faux —
--     juste, mais par accident ;
--   - défaire le jumelage = supprimer son invitation (droit existant : son
--     auteur ou un admin) ; le jumeau part en cascade. Pas de RPC de plus ;
--   - remote_code nul = jumeau en attente : lancé depuis Agora, il attend la
--     réponse d'Arpente. Son format dépend de l'app (Arpente : 6 caractères).
--     Un jumeau complet ne change pas de code (twin_exists) : un lien forgé
--     ne doit pas pouvoir rediriger les membres vers un autre groupe. Pour
--     changer de jumeau, on défait d'abord ;
--   - on n'écrit un jumeau que par twin_group (aucun GRANT d'écriture), qui
--     verrouille la ligne du groupe : deux admins qui jumellent en même temps
--     se sérialisent.
--
-- Invariants (supabase/tests/group_twins_test.sql) : seuls les admins
-- jumellent ; un jumeau par groupe et par app ; seuls les membres le lisent ;
-- son invitation n'expire pas et disparaît avec lui.
-- =============================================================================

alter table public.group_invites alter column expires_at drop not null;

create type public.twin_app as enum ('arpente');

create table public.group_twins (
  group_id uuid not null references public.groups (id) on delete cascade,
  app public.twin_app not null,
  invite_code text not null unique references public.group_invites (code) on delete cascade,
  remote_code text,
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (group_id, app),
  constraint group_twins_remote_code_format check (
    remote_code is null
    or (app = 'arpente' and remote_code ~ '^[A-HJ-NP-Z2-9]{6}$')
  )
);

alter table public.group_twins enable row level security;
revoke all on public.group_twins from anon, authenticated;
grant select on public.group_twins to authenticated;
grant all on public.group_twins to service_role;

create policy "group_twins: membres" on public.group_twins
  for select to authenticated using (private.is_group_member(group_id));

-- Crée le jumeau (et son invitation sans échéance), ou le complète du code
-- distant. Rend le code de l'invitation à donner à l'autre app. Admins seuls.
create function public.twin_group(
  p_group_id uuid,
  p_app public.twin_app,
  p_remote_code text default null
)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  v_remote text := nullif(upper(btrim(p_remote_code)), '');
  v_code text;
  v_current text;
begin
  if not private.is_group_admin(p_group_id) then
    raise exception 'not_group_admin' using errcode = '42501';
  end if;
  perform 1 from public.groups g where g.id = p_group_id for update;
  if v_remote is not null and not (p_app = 'arpente' and v_remote ~ '^[A-HJ-NP-Z2-9]{6}$') then
    raise exception 'invalid_twin_code' using errcode = '22023';
  end if;
  select gt.invite_code, gt.remote_code into v_code, v_current
  from public.group_twins gt
  where gt.group_id = p_group_id and gt.app = p_app;
  if not found then
    v_code := private.random_invite_code();
    insert into public.group_invites (code, group_id, expires_at) values (v_code, p_group_id, null);
    insert into public.group_twins (group_id, app, invite_code, remote_code)
    values (p_group_id, p_app, v_code, v_remote);
  elsif v_remote is not null and v_current is not null and v_current <> v_remote then
    raise exception 'twin_exists' using errcode = '23505';
  elsif v_remote is not null and v_current is null then
    update public.group_twins gt set remote_code = v_remote
    where gt.group_id = p_group_id and gt.app = p_app;
  end if;
  return v_code;
end;
$$;

revoke execute on function public.twin_group(uuid, public.twin_app, text) from public, anon;
grant execute on function public.twin_group(uuid, public.twin_app, text) to authenticated;

-- Les deux lectures d'une invitation, à l'identique de 20260922000000_group_management.sql
-- hormis l'échéance nulle, dite en clair.
create or replace function public.join_group(p_code text, p_share_level public.visibility default 'busy')
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
     or (v_invite.expires_at is not null and v_invite.expires_at <= now())
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

create or replace function public.invite_preview(p_code text)
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
     or (v_invite.expires_at is not null and v_invite.expires_at <= now())
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

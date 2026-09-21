-- =============================================================================
-- Suppression de compte, exigée par le Play Store pour toute app qui crée des
-- comptes (dans l'app et depuis le web, que la version web d'Agora couvre).
--
-- Règles :
--   - chaque groupe dont la personne est propriétaire est transmis à l'admin
--     le plus ancien, sinon au membre le plus ancien ; un groupe sans autre
--     membre est supprimé, avec son agenda et ses rdv ;
--   - tout le reste part en cascade depuis auth.users : profil, agendas
--     personnels, rdv et occurrences, URL iCal, appartenances, identités et
--     sessions GoTrue ;
--   - les rdv de groupe qu'elle a proposés restent (contenu partagé), sans
--     auteur (events.created_by → null), de même que ses invitations.
--
-- Choix non évident : une RPC plutôt qu'une Edge Function. Le Supabase
-- auto-hébergé d'Agora n'a pas d'edge runtime, et la suppression doit de
-- toute façon transmettre les groupes dans la même transaction que
-- l'effacement : un groupe ne reste jamais sans propriétaire.
-- =============================================================================

create function public.delete_my_account()
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_group_id uuid;
  v_heir uuid;
begin
  if v_user is null or not exists (select 1 from auth.users u where u.id = v_user) then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  -- Verrouille d'abord chaque groupe dont la personne est membre, dans un
  -- ordre fixe (pas d'interblocage), AVANT de lire son rôle. Deux suppressions
  -- qui touchent un même groupe s'exécutent ainsi l'une après l'autre. Sans ce
  -- verrou, l'héritier désigné qui se supprimait en même temps avait lu son
  -- rôle d'avant la transmission : il disparaissait sans rien transmettre,
  -- laissant un groupe sans aucun membre (reproduit par
  -- supabase/checks/account_deletion_race.sh).
  perform 1
  from public.groups g
  where g.id in (select gm.group_id from public.group_members gm where gm.user_id = v_user)
  order by g.id
  for update;

  -- Lu après les verrous : en READ COMMITTED, cette requête voit les
  -- transmissions que les suppressions concurrentes viennent de valider.
  for v_group_id in
    select gm.group_id from public.group_members gm
    where gm.user_id = v_user and gm.role = 'owner'
  loop
    select gm.user_id into v_heir
    from public.group_members gm
    where gm.group_id = v_group_id and gm.user_id <> v_user
    order by (gm.role = 'admin') desc, gm.joined_at, gm.user_id
    limit 1
    for update;

    if v_heir is null then
      delete from public.groups g where g.id = v_group_id;
    else
      update public.group_members gm set role = 'owner'
      where gm.group_id = v_group_id and gm.user_id = v_heir;
    end if;
  end loop;

  delete from auth.users u where u.id = v_user;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- =============================================================================
-- Ce qu'une suppression de compte laisse derrière elle.
--
-- Un rdv proposé à un groupe lui appartient : delete_my_account ne l'efface
-- pas, il perd seulement son auteur (created_by passe à null) et garde son
-- texte libre — titre, lieu, description — qui peut encore nommer la
-- personne. C'est voulu : les autres ont calé leur samedi dessus et y ont
-- répondu.
--
-- Mais personne ne le savait au moment d'appuyer sur « Supprimer mon
-- compte ». Ces deux fonctions permettent à l'app de le dire, et d'effacer
-- d'abord si on préfère :
--   - my_proposed_group_events : ce qui restera, avec le nom du groupe ;
--   - delete_my_proposed_group_events : les efface, et rend leur nombre.
--
-- Choix non évidents :
--   - SECURITY INVOKER : aucune des deux n'ouvre de droit nouveau. La RLS
--     des rdv dit déjà qui peut lire (les membres du groupe) et qui peut
--     supprimer (l'auteur ou un admin). Une fonction SECURITY DEFINER
--     devrait refaire ces contrôles, et pourrait se tromper ;
--   - les occurrences modifiées (series_id non nul) sont écartées : elles
--     appartiennent à une série déjà comptée, et les afficher ferait croire
--     à deux rdv là où il n'y en a qu'un. Supprimer la série les emporte.
--
-- Invariant : ces fonctions ne touchent QUE les rdv d'un agenda de groupe
-- créés par l'appelant. Un rdv personnel part avec le compte de toute façon,
-- un rdv proposé par quelqu'un d'autre ne bouge pas.
-- =============================================================================

create function public.my_proposed_group_events()
returns table (
  event_id uuid,
  title text,
  starts_at timestamptz,
  group_id uuid,
  group_name text
)
language sql stable security invoker set search_path = '' as $$
  select e.id, e.title, e.starts_at, g.id, g.name
  from public.events e
  join public.calendars c on c.id = e.calendar_id
  join public.groups g on g.id = c.group_id
  where e.created_by = (select auth.uid())
    and e.series_id is null
  order by e.starts_at;
$$;

create function public.delete_my_proposed_group_events()
returns integer
language plpgsql volatile security invoker set search_path = '' as $$
declare
  v_deleted integer;
begin
  with mine as (
    select e.id
    from public.events e
    join public.calendars c on c.id = e.calendar_id
    where c.group_id is not null
      and e.created_by = (select auth.uid())
      and e.series_id is null
  )
  delete from public.events e using mine where e.id = mine.id;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke execute on function public.my_proposed_group_events(),
  public.delete_my_proposed_group_events()
  from public, anon;
grant execute on function public.my_proposed_group_events(),
  public.delete_my_proposed_group_events()
  to authenticated;

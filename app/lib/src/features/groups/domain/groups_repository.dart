/// Accès aux groupes de l'utilisateur : les siens, leurs membres, les
/// invitations, et l'agenda de chaque groupe.
///
/// Invariants : seules des `AppException` en sortent ; l'agenda d'un groupe
/// ne se lit que par `group_agenda()` (la règle de vie privée vit en base,
/// jamais dans l'app) ; rejoindre fixe le partage dans la même transaction.
library;

import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';

abstract interface class GroupsRepository {
  /// Groupes dont l'utilisateur est membre, du plus ancien au plus récent.
  Future<List<MyGroup>> fetchMyGroups();

  /// Crée le groupe (l'utilisateur en devient propriétaire) ; son id.
  Future<String> createGroup({required String name, String? description});

  /// Renomme le groupe ; sa description ne bouge pas (admins seulement).
  Future<void> renameGroup(String groupId, String name);

  /// Supprime le groupe pour tous (propriétaire seulement).
  Future<void> deleteGroup(String groupId);

  /// Membres du groupe, du plus ancien au plus récent.
  Future<List<GroupMember>> fetchMembers(String groupId);

  Future<void> setMyShareLevel(String groupId, ShareLevel level);

  /// Quitte le groupe (pas le propriétaire, qui doit d'abord le transmettre).
  Future<void> leaveGroup(String groupId);

  /// Exclut un simple membre (admin ou propriétaire).
  Future<void> removeMember(String groupId, String userId);

  /// Nomme admin ou repasse membre (propriétaire seulement).
  Future<void> setRole(String groupId, String userId, GroupRole role);

  /// Transmet le groupe ; l'utilisateur en devient admin.
  Future<void> transferGroup(String groupId, String newOwnerId);

  /// Dernière invitation encore valable créée par l'utilisateur, ou `null`.
  Future<GroupInvite?> findMyInvite(String groupId);

  Future<GroupInvite> createInvite(String groupId);

  Future<void> revokeInvite(String code);

  Future<InvitePreview> previewInvite(String code);

  /// Rejoint le groupe avec le partage choisi ; l'id du groupe.
  Future<String> joinGroup(String code, ShareLevel shareLevel);

  /// Créneaux du groupe de [from] (inclus) à [to] (exclu), un trimestre au
  /// plus, déjà passés par la règle de vie privée.
  Future<List<GroupAgendaItem>> fetchGroupAgenda(
    String groupId,
    DateTime from,
    DateTime to,
  );
}

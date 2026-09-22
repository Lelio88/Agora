/// Groupes de l'utilisateur, leurs membres, leur agenda, et le service qui
/// les crée, règle, rejoint et quitte.
///
/// Choix non évidents :
/// - l'agenda d'un groupe n'a pas de temps réel : les rdv des autres membres
///   ne sont pas lisibles en direct (la RLS les cache), seul `group_agenda`
///   les résout. Il se relit à l'ouverture, au changement de plage, après
///   chaque action, et à la demande ;
/// - chaque action réussie invalide ce qu'elle a changé (liste, membres,
///   agenda), comme `CalendarService`.
library;

import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/features/groups/domain/groups_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => throw UnimplementedError(
    'groupsRepositoryProvider must be overridden at the composition root.',
  ),
);

final myGroupsProvider = FutureProvider<List<MyGroup>>(
  (ref) => ref.watch(groupsRepositoryProvider).fetchMyGroups(),
);

/// Un groupe de l'utilisateur ; `null` s'il n'en est plus membre.
final myGroupProvider = FutureProvider.autoDispose.family<MyGroup?, String>((
  ref,
  groupId,
) async {
  final groups = await ref.watch(myGroupsProvider.future);
  return groups.where((g) => g.id == groupId).firstOrNull;
});

final groupMembersProvider = FutureProvider.autoDispose
    .family<List<GroupMember>, String>(
      (ref, groupId) =>
          ref.watch(groupsRepositoryProvider).fetchMembers(groupId),
    );

/// Plage de l'agenda d'un groupe : [from, to[ en UTC.
final class GroupAgendaQuery {
  const GroupAgendaQuery({
    required this.groupId,
    required this.from,
    required this.to,
  });

  final String groupId;
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is GroupAgendaQuery &&
      other.groupId == groupId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(groupId, from, to);
}

final groupAgendaProvider = FutureProvider.autoDispose
    .family<List<GroupAgendaItem>, GroupAgendaQuery>(
      (ref, query) => ref
          .watch(groupsRepositoryProvider)
          .fetchGroupAgenda(query.groupId, query.from, query.to),
    );

final invitePreviewProvider = FutureProvider.autoDispose
    .family<InvitePreview, String>(
      (ref, code) => ref.watch(groupsRepositoryProvider).previewInvite(code),
    );

final class GroupsService {
  const GroupsService(this._repository, this._invalidate);

  final GroupsRepository _repository;

  /// Invalide ce qui dépend d'un groupe ([groupId] nul : la liste seule).
  final void Function(String? groupId) _invalidate;

  Future<String> create({required String name, String? description}) async {
    final id = await _repository.createGroup(
      name: name,
      description: description,
    );
    _invalidate(null);
    return id;
  }

  Future<void> rename(String groupId, {required String name}) =>
      _then(groupId, _repository.renameGroup(groupId, name));

  Future<void> delete(String groupId) =>
      _then(groupId, _repository.deleteGroup(groupId));

  Future<void> setMyShareLevel(String groupId, ShareLevel level) =>
      _then(groupId, _repository.setMyShareLevel(groupId, level));

  Future<void> leave(String groupId) =>
      _then(groupId, _repository.leaveGroup(groupId));

  Future<void> removeMember(String groupId, String userId) =>
      _then(groupId, _repository.removeMember(groupId, userId));

  Future<void> setRole(String groupId, String userId, GroupRole role) =>
      _then(groupId, _repository.setRole(groupId, userId, role));

  Future<void> transfer(String groupId, String newOwnerId) =>
      _then(groupId, _repository.transferGroup(groupId, newOwnerId));

  /// L'invitation en cours de l'utilisateur, ou une nouvelle.
  Future<GroupInvite> currentInvite(String groupId) async =>
      await _repository.findMyInvite(groupId) ??
      await _repository.createInvite(groupId);

  Future<void> revokeInvite(String code) => _repository.revokeInvite(code);

  Future<String> join(String code, ShareLevel shareLevel) async {
    final groupId = await _repository.joinGroup(code, shareLevel);
    _invalidate(groupId);
    return groupId;
  }

  Future<void> _then(String groupId, Future<void> action) async {
    await action;
    _invalidate(groupId);
  }
}

final groupsServiceProvider = Provider<GroupsService>(
  (ref) => GroupsService(ref.watch(groupsRepositoryProvider), (groupId) {
    ref.invalidate(myGroupsProvider);
    if (groupId == null) return;
    ref
      ..invalidate(groupMembersProvider(groupId))
      ..invalidate(groupAgendaProvider);
  }),
);

/// Invitation ouverte par lien alors que personne n'était connecté : le
/// routeur la retient le temps de la connexion ou de l'inscription, puis y
/// ramène. L'écran « Rejoindre » la consomme.
final class PendingInvite {
  String? code;
}

final pendingInviteProvider = Provider<PendingInvite>((ref) => PendingInvite());

/// Un code d'invitation plausible (8 caractères, alphabet sans ambiguïté,
/// casse ignorée) : tout le reste est ignoré avant même le serveur.
bool looksLikeInviteCode(String code) =>
    RegExp(r'^[A-HJ-NP-Za-hj-np-z2-9]{8}$').hasMatch(code.trim());

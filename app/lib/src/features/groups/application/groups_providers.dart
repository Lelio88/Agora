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

import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/features/groups/domain/groups_repository.dart';
import 'package:agora/src/features/groups/domain/member_agenda.dart';
import 'package:agora/src/features/groups/domain/twin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => throw UnimplementedError(
    'groupsRepositoryProvider must be overridden at the composition root.',
  ),
);

final myGroupsProvider = FutureProvider<List<MyGroup>>((ref) async {
  // Relus à chaque changement de compte ; aucun sans compte.
  final repository = ref.watch(groupsRepositoryProvider);
  if (await ref.watch(currentUserIdProvider.future) == null) return const [];
  return repository.fetchMyGroups();
});

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

/// Les membres de tous mes groupes, une fois chacun, sans moi, par nom :
/// ceux à qui un proche peut être relié.
final coMembersProvider = FutureProvider.autoDispose<List<GroupMember>>((
  ref,
) async {
  final groups = await ref.watch(myGroupsProvider.future);
  final lists = await Future.wait([
    for (final group in groups)
      ref.watch(groupMembersProvider(group.id).future),
  ]);
  final byId = <String, GroupMember>{
    for (final members in lists)
      for (final member in members)
        if (!member.isMe) member.userId: member,
  };
  return byId.values.toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));
});

/// Ce que le membre [MemberAgendaQuery.userId] partage dans mes groupes, sur
/// une plage.
final class MemberAgendaQuery {
  const MemberAgendaQuery({
    required this.userId,
    required this.from,
    required this.to,
  });

  final String userId;
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is MemberAgendaQuery &&
      other.userId == userId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(userId, from, to);
}

/// Les créneaux d'un membre dans les groupes que j'ai en commun avec lui,
/// réunis ([memberSharedAgenda]) : chacun passe par `group_agenda()`, la
/// règle de vie privée reste en base.
final memberAgendaProvider = FutureProvider.autoDispose
    .family<List<GroupAgendaItem>, MemberAgendaQuery>((ref, query) async {
      final groups = await ref.watch(myGroupsProvider.future);
      final members = await Future.wait([
        for (final group in groups)
          ref.watch(groupMembersProvider(group.id).future),
      ]);
      final common = [
        for (final (index, group) in groups.indexed)
          if (members[index].any((m) => m.userId == query.userId)) group.id,
      ];
      final agendas = await Future.wait([
        for (final groupId in common)
          ref.watch(
            groupAgendaProvider(
              GroupAgendaQuery(
                groupId: groupId,
                from: query.from,
                to: query.to,
              ),
            ).future,
          ),
      ]);
      return memberSharedAgenda(query.userId, agendas);
    });

/// Jumeaux d'un groupe dans d'autres apps (Arpente).
final groupTwinsProvider = FutureProvider.autoDispose
    .family<List<GroupTwin>, String>(
      (ref, groupId) => ref.watch(groupsRepositoryProvider).fetchTwins(groupId),
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

  /// Crée ou complète le jumeau du groupe dans [app] ; le code de
  /// l'invitation à donner à l'autre app.
  Future<String> twin(String groupId, TwinApp app, {String? remoteCode}) async {
    final code = await _repository.twinGroup(
      groupId,
      app,
      remoteCode: remoteCode,
    );
    _invalidate(groupId);
    return code;
  }

  /// Défait le jumelage : l'invitation donnée à l'autre app n'ouvre plus
  /// rien (le jumeau part avec elle).
  Future<void> unlinkTwin(String groupId, GroupTwin twin) =>
      _then(groupId, _repository.revokeInvite(twin.inviteCode));

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
      ..invalidate(groupTwinsProvider(groupId))
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

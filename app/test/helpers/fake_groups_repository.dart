import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/features/groups/domain/groups_repository.dart';

import 'fakes.dart';

/// Un membre d'un faux groupe.
final class FakeMember {
  FakeMember(this.userId, this.name, this.role, this.share);

  final String userId;
  final String name;
  GroupRole role;
  ShareLevel share;
}

/// Un faux groupe : nom, membres, créneaux de son agenda.
final class FakeGroup {
  FakeGroup(this.id, this.name, {this.description, List<FakeMember>? members})
    : members = members ?? [];

  final String id;
  String name;
  String? description;
  final List<FakeMember> members;
  final agenda = <GroupAgendaItem>[];
}

/// Faux [GroupsRepository] en mémoire, qui applique les règles du serveur
/// que l'app observe : seul le propriétaire gère les rôles et transmet, il
/// ne quitte pas sans transmettre, une invitation valable est réutilisée,
/// un code inconnu est refusé sans dire pourquoi.
class FakeGroupsRepository implements GroupsRepository {
  static const me = FakeAuthRepository.userId;

  final groups = <String, FakeGroup>{};
  final invites = <String, ({String groupId, String createdBy})>{};
  final calls = <String>[];
  AppException? nextError;
  int _nextId = 1;
  int _nextCode = 0;

  /// Ajoute un groupe dont l'utilisateur est membre avec [myRole].
  FakeGroup seedGroup(
    String id,
    String name, {
    GroupRole myRole = GroupRole.owner,
    ShareLevel myShare = ShareLevel.busy,
    List<FakeMember> others = const [],
  }) => groups[id] = FakeGroup(
    id,
    name,
    members: [FakeMember(me, 'Zoé', myRole, myShare), ...others],
  );

  /// Ajoute une invitation valable, créée par [createdBy].
  void seedInvite(String code, String groupId, {String createdBy = 'other'}) =>
      invites[code] = (groupId: groupId, createdBy: createdBy);

  void _record(String call) {
    calls.add(call);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  FakeGroup _group(String groupId) {
    final group = groups[groupId];
    if (group == null || !group.members.any((m) => m.userId == me)) {
      throw const NotGroupMemberException();
    }
    return group;
  }

  FakeMember _mine(FakeGroup group) =>
      group.members.firstWhere((m) => m.userId == me);

  @override
  Future<List<MyGroup>> fetchMyGroups() async {
    _record('fetchMyGroups');
    return [
      for (final group in groups.values)
        for (final member in group.members.where((m) => m.userId == me))
          MyGroup(
            id: group.id,
            name: group.name,
            role: member.role,
            shareLevel: member.share,
          ),
    ];
  }

  @override
  Future<String> createGroup({
    required String name,
    String? description,
  }) async {
    _record('createGroup');
    final id = 'group-${_nextId++}';
    seedGroup(id, name.trim()).description = description;
    return id;
  }

  @override
  Future<void> renameGroup(String groupId, String name) async {
    _record('renameGroup');
    final group = _group(groupId);
    if (!_mine(group).role.canManage) throw const NotGroupOwnerException();
    group.name = name.trim();
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    _record('deleteGroup');
    final group = _group(groupId);
    if (_mine(group).role != GroupRole.owner) {
      throw const NotGroupOwnerException();
    }
    groups.remove(groupId);
  }

  @override
  Future<List<GroupMember>> fetchMembers(String groupId) async {
    _record('fetchMembers');
    return [
      for (final m in _group(groupId).members)
        GroupMember(
          userId: m.userId,
          displayName: m.name,
          role: m.role,
          shareLevel: m.share,
          isMe: m.userId == me,
        ),
    ];
  }

  @override
  Future<void> setMyShareLevel(String groupId, ShareLevel level) async {
    _record('setMyShareLevel');
    _mine(_group(groupId)).share = level;
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    _record('leaveGroup');
    final group = _group(groupId);
    if (_mine(group).role == GroupRole.owner) {
      throw const NotGroupOwnerException();
    }
    group.members.removeWhere((m) => m.userId == me);
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    _record('removeMember');
    _group(groupId).members
        .removeWhere((m) => m.userId == userId && m.role == GroupRole.member);
  }

  @override
  Future<void> setRole(String groupId, String userId, GroupRole role) async {
    _record('setRole');
    final group = _group(groupId);
    if (_mine(group).role != GroupRole.owner) {
      throw const NotGroupOwnerException();
    }
    group.members.firstWhere((m) => m.userId == userId).role = role;
  }

  @override
  Future<void> transferGroup(String groupId, String newOwnerId) async {
    _record('transferGroup');
    final group = _group(groupId);
    if (_mine(group).role != GroupRole.owner) {
      throw const NotGroupOwnerException();
    }
    _mine(group).role = GroupRole.admin;
    group.members.firstWhere((m) => m.userId == newOwnerId).role =
        GroupRole.owner;
  }

  @override
  Future<GroupInvite?> findMyInvite(String groupId) async {
    _record('findMyInvite');
    final code = invites.entries
        .where((e) => e.value.groupId == groupId && e.value.createdBy == me)
        .map((e) => e.key)
        .lastOrNull;
    return code == null ? null : _invite(code);
  }

  @override
  Future<GroupInvite> createInvite(String groupId) async {
    _record('createInvite');
    _group(groupId);
    final code = 'CODE${(_nextCode++).toString().padLeft(4, '2')}'
        .replaceAll('0', 'Z')
        .replaceAll('1', 'Y');
    invites[code] = (groupId: groupId, createdBy: me);
    return _invite(code);
  }

  GroupInvite _invite(String code) =>
      GroupInvite(code: code, expiresAt: DateTime.utc(2030));

  @override
  Future<void> revokeInvite(String code) async {
    _record('revokeInvite');
    invites.remove(code);
  }

  @override
  Future<InvitePreview> previewInvite(String code) async {
    _record('previewInvite');
    final invite = invites[code.toUpperCase()];
    final group = invite == null ? null : groups[invite.groupId];
    if (group == null) throw const InvalidInviteException();
    return InvitePreview(
      groupId: group.id,
      name: group.name,
      memberCount: group.members.length,
      isMember: group.members.any((m) => m.userId == me),
    );
  }

  /// Dernier partage choisi en rejoignant.
  ShareLevel? joinedWith;

  @override
  Future<String> joinGroup(String code, ShareLevel shareLevel) async {
    _record('joinGroup');
    final invite = invites[code.toUpperCase()];
    final group = invite == null ? null : groups[invite.groupId];
    if (group == null) throw const InvalidInviteException();
    joinedWith = shareLevel;
    if (!group.members.any((m) => m.userId == me)) {
      group.members.add(FakeMember(me, 'Zoé', GroupRole.member, shareLevel));
    }
    return group.id;
  }

  @override
  Future<List<GroupAgendaItem>> fetchGroupAgenda(
    String groupId,
    DateTime from,
    DateTime to,
  ) async {
    _record('fetchGroupAgenda');
    return _group(groupId).agenda
        .where((i) => i.start.isBefore(to) && i.end.isAfter(from))
        .toList();
  }
}

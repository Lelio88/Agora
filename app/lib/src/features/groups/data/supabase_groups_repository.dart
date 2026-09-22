/// [GroupsRepository] sur PostgREST.
///
/// Choix non évidents :
/// - ses groupes se lisent depuis `group_members` (sa ligne porte rôle et
///   partage) avec le groupe en jointure ; les membres, avec leur profil
///   en jointure (la RLS n'ouvre que les profils des co-membres) ;
/// - quitter, c'est supprimer SA ligne de `group_members` : l'id de
///   l'utilisateur vient de la session, jamais de l'écran ;
/// - l'agenda du groupe passe par la RPC `group_agenda`, qui applique la
///   règle de vie privée : l'app ne voit jamais un titre non partagé.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/features/groups/domain/groups_repository.dart';
import 'package:agora/src/supabase/postgrest_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseGroupsRepository implements GroupsRepository {
  const SupabaseGroupsRepository(this._client);

  final SupabaseClient _client;

  String get _me {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const NotGroupMemberException();
    return id;
  }

  @override
  Future<List<MyGroup>> fetchMyGroups() => guardPostgrest(() async {
    final rows = await _client
        .from('group_members')
        .select('role, share_level, groups!inner(id, name, description)')
        .eq('user_id', _me)
        .order('joined_at', ascending: true);
    return [
      for (final row in rows)
        MyGroup(
          id: row['groups']['id'] as String,
          name: row['groups']['name'] as String,
          description: row['groups']['description'] as String?,
          role: GroupRole.fromCode(row['role'] as String),
          shareLevel: ShareLevel.fromCode(row['share_level'] as String?),
        ),
    ];
  });

  @override
  Future<String> createGroup({required String name, String? description}) =>
      guardPostgrest(
        () async => await _client.rpc<String>(
          'create_group',
          params: {
            'p_name': name.trim(),
            'p_description': _nullIfBlank(description),
          },
        ),
      );

  // Le nom seul : une colonne absente du PATCH n'est pas touchée, alors
  // qu'une description `null` envoyée l'effacerait.
  @override
  Future<void> renameGroup(String groupId, String name) => guardPostgrest(
    () =>
        _client.from('groups').update({'name': name.trim()}).eq('id', groupId),
  );

  @override
  Future<void> deleteGroup(String groupId) =>
      guardPostgrest(() => _client.from('groups').delete().eq('id', groupId));

  @override
  Future<List<GroupMember>> fetchMembers(String groupId) =>
      guardPostgrest(() async {
        final me = _me;
        final rows = await _client
            .from('group_members')
            .select('user_id, role, share_level, profiles(display_name)')
            .eq('group_id', groupId)
            .order('joined_at', ascending: true);
        return [
          for (final row in rows)
            GroupMember(
              userId: row['user_id'] as String,
              displayName:
                  (row['profiles'] as Map<String, dynamic>?)?['display_name']
                      as String? ??
                  '',
              role: GroupRole.fromCode(row['role'] as String),
              shareLevel: ShareLevel.fromCode(row['share_level'] as String?),
              isMe: row['user_id'] == me,
            ),
        ];
      });

  @override
  Future<void> setMyShareLevel(String groupId, ShareLevel level) =>
      guardPostgrest(
        () => _client
            .from('group_members')
            .update({'share_level': level.name})
            .eq('group_id', groupId)
            .eq('user_id', _me),
      );

  @override
  Future<void> leaveGroup(String groupId) => guardPostgrest(
    () => _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', _me),
  );

  @override
  Future<void> removeMember(String groupId, String userId) => guardPostgrest(
    () => _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId),
  );

  @override
  Future<void> setRole(String groupId, String userId, GroupRole role) =>
      guardPostgrest(
        () => _client.rpc<void>(
          'set_member_role',
          params: {
            'p_group_id': groupId,
            'p_user_id': userId,
            'p_role': role.name,
          },
        ),
      );

  @override
  Future<void> transferGroup(String groupId, String newOwnerId) =>
      guardPostgrest(
        () => _client.rpc<void>(
          'transfer_group',
          params: {'p_group_id': groupId, 'p_new_owner': newOwnerId},
        ),
      );

  @override
  Future<GroupInvite?> findMyInvite(String groupId) => guardPostgrest(() async {
    final rows = await _client
        .from('group_invites')
        .select('code, expires_at, max_uses, uses')
        .eq('group_id', groupId)
        .eq('created_by', _me)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.single;
    final maxUses = row['max_uses'] as int?;
    if (maxUses != null && (row['uses'] as int) >= maxUses) return null;
    return _toInvite(row);
  });

  @override
  Future<GroupInvite> createInvite(String groupId) => guardPostgrest(() async {
    final code = await _client.rpc<String>(
      'create_invite',
      params: {'p_group_id': groupId},
    );
    final row = await _client
        .from('group_invites')
        .select('code, expires_at')
        .eq('code', code)
        .single();
    return _toInvite(row);
  });

  @override
  Future<void> revokeInvite(String code) => guardPostgrest(
    () => _client.from('group_invites').delete().eq('code', code),
  );

  @override
  Future<InvitePreview> previewInvite(String code) => guardPostgrest(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'invite_preview',
      params: {'p_code': code},
    );
    if (rows.isEmpty) throw const InvalidInviteException();
    final row = rows.single as Map<String, dynamic>;
    return InvitePreview(
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      memberCount: row['member_count'] as int,
      isMember: row['is_member'] as bool,
    );
  });

  @override
  Future<String> joinGroup(String code, ShareLevel shareLevel) =>
      guardPostgrest(
        () async => await _client.rpc<String>(
          'join_group',
          params: {'p_code': code, 'p_share_level': shareLevel.name},
        ),
      );

  @override
  Future<List<GroupAgendaItem>> fetchGroupAgenda(
    String groupId,
    DateTime from,
    DateTime to,
  ) => guardPostgrest(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'group_agenda',
      params: {
        'p_group_id': groupId,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );
    return rows
        .cast<Map<String, dynamic>>()
        .map(_toAgendaItem)
        .toList(growable: false);
  });

  static GroupInvite _toInvite(Map<String, dynamic> row) => GroupInvite(
    code: row['code'] as String,
    expiresAt: DateTime.parse(row['expires_at'] as String).toUtc(),
  );

  static GroupAgendaItem _toAgendaItem(Map<String, dynamic> row) =>
      GroupAgendaItem(
        eventId: row['event_id'] as String?,
        userId: row['user_id'] as String?,
        isGroupEvent: row['is_group_event'] as bool,
        level: ShareLevel.fromCode(row['level'] as String?),
        title: row['title'] as String?,
        location: row['location'] as String?,
        start: DateTime.parse(row['starts_at'] as String).toUtc(),
        end: DateTime.parse(row['ends_at'] as String).toUtc(),
        isAllDay: row['all_day'] as bool,
      );

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

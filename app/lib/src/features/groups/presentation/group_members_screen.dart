/// Membres d'un groupe : ce que l'utilisateur y partage (réglable), puis la
/// liste des membres avec leur rôle et leur partage, et les actions que son
/// rôle permet.
///
/// Qui peut quoi (le serveur le vérifie de toute façon) :
/// - le propriétaire nomme ou retire des admins, transmet le groupe, exclut
///   un simple membre ;
/// - un admin exclut un simple membre ;
/// - un simple membre n'a aucune action sur les autres.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/groups/presentation/group_labels.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _MemberAction { makeAdmin, removeAdmin, transfer, remove }

class GroupMembersScreen extends ConsumerWidget {
  const GroupMembersScreen({required this.groupId, super.key});

  final String groupId;

  static Future<void> show(BuildContext context, String groupId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroupMembersScreen(groupId: groupId),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final group = ref.watch(myGroupProvider(groupId)).value;
    final members = ref.watch(groupMembersProvider(groupId));
    return Scaffold(
      key: GroupKeys.membersScreen,
      appBar: AppBar(title: Text(l10n.membersTitle)),
      body: AsyncValueWidget<List<GroupMember>>(
        value: members,
        data: (list) => ListView(
          children: [
            if (group != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  l10n.myShareLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              RadioGroup<ShareLevel>(
                groupValue: group.shareLevel,
                onChanged: (level) {
                  if (level == null || level == group.shareLevel) return;
                  _run(
                    context,
                    () => ref
                        .read(groupsServiceProvider)
                        .setMyShareLevel(groupId, level),
                    l10n.shareSaved,
                  );
                },
                child: Column(
                  children: [
                    for (final level in ShareLevel.values)
                      RadioListTile<ShareLevel>(
                        key: GroupKeys.myShare(level),
                        value: level,
                        title: Text(shareLevelLabel(level, l10n)),
                      ),
                  ],
                ),
              ),
              const Divider(),
            ],
            for (final (rank, member) in list.indexed)
              _MemberTile(
                member: member,
                color: memberColor(rank, Theme.of(context).colorScheme),
                actions: _actionsFor(group?.role, member),
                onAction: (action) => _onAction(context, ref, member, action),
              ),
          ],
        ),
      ),
    );
  }

  static List<_MemberAction> _actionsFor(GroupRole? myRole, GroupMember m) {
    if (myRole == null || m.isMe || m.role == GroupRole.owner) return const [];
    return switch (myRole) {
      GroupRole.owner => [
        if (m.role == GroupRole.member) _MemberAction.makeAdmin,
        if (m.role == GroupRole.admin) _MemberAction.removeAdmin,
        _MemberAction.transfer,
        if (m.role == GroupRole.member) _MemberAction.remove,
      ],
      GroupRole.admin => [if (m.role == GroupRole.member) _MemberAction.remove],
      GroupRole.member => const [],
    };
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
    _MemberAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(groupsServiceProvider);
    switch (action) {
      case _MemberAction.makeAdmin:
        await _run(
          context,
          () => service.setRole(groupId, member.userId, GroupRole.admin),
          l10n.roleChanged,
        );
      case _MemberAction.removeAdmin:
        await _run(
          context,
          () => service.setRole(groupId, member.userId, GroupRole.member),
          l10n.roleChanged,
        );
      case _MemberAction.transfer:
        final confirmed = await confirmAction(
          context,
          title: l10n.transferTitle(member.displayName),
          body: l10n.transferBody(member.displayName),
          action: l10n.transferGroup,
        );
        if (!confirmed || !context.mounted) return;
        await _run(
          context,
          () => service.transfer(groupId, member.userId),
          l10n.groupTransferred,
        );
      case _MemberAction.remove:
        final confirmed = await confirmAction(
          context,
          title: l10n.removeMemberTitle(member.displayName),
          body: l10n.leaveGroupBody,
          action: l10n.removeMember,
        );
        if (!confirmed || !context.mounted) return;
        await _run(
          context,
          () => service.removeMember(groupId, member.userId),
          l10n.memberRemoved,
        );
    }
  }

  static Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.color,
    required this.actions,
    required this.onAction,
  });

  final GroupMember member;
  final Color color;
  final List<_MemberAction> actions;
  final ValueChanged<_MemberAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = member.isMe
        ? '${member.displayName} (${l10n.memberYou})'
        : member.displayName;
    return ListTile(
      key: GroupKeys.memberTile(member.userId),
      leading: CircleAvatar(backgroundColor: color, radius: 10),
      title: Text(name),
      subtitle: Text(
        '${roleLabel(member.role, l10n)} · '
        '${l10n.memberShares(shareLevelLabel(member.shareLevel, l10n))}',
      ),
      trailing: actions.isEmpty
          ? null
          : PopupMenuButton<_MemberAction>(
              key: GroupKeys.memberMenu(member.userId),
              onSelected: onAction,
              itemBuilder: (context) => [
                for (final action in actions)
                  PopupMenuItem(
                    key: switch (action) {
                      _MemberAction.makeAdmin => GroupKeys.makeAdmin,
                      _MemberAction.removeAdmin => GroupKeys.removeAdmin,
                      _MemberAction.transfer => GroupKeys.transfer,
                      _MemberAction.remove => GroupKeys.remove,
                    },
                    value: action,
                    child: Text(switch (action) {
                      _MemberAction.makeAdmin => l10n.makeAdmin,
                      _MemberAction.removeAdmin => l10n.removeAdmin,
                      _MemberAction.transfer => l10n.transferGroup,
                      _MemberAction.remove => l10n.removeMember,
                    }),
                  ),
              ],
            ),
    );
  }
}

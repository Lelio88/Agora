/// Liste des groupes de l'utilisateur (onglet « Groupes » de l'accueil) :
/// ouvrir un groupe, en créer un, en rejoindre un avec un code.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/presentation/group_editor_screen.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/groups/presentation/group_labels.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(myGroupsProvider);
    return Scaffold(
      key: GroupKeys.listScreen,
      floatingActionButton: FloatingActionButton.extended(
        key: GroupKeys.newGroup,
        // Les onglets de l'accueil coexistent : chaque bouton a son tag.
        heroTag: GroupKeys.newGroup,
        icon: const Icon(Icons.group_add_outlined),
        label: Text(l10n.newGroupButton),
        onPressed: () => _create(context, ref),
      ),
      body: AsyncValueWidget<List<MyGroup>>(
        value: groups,
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: GroupKeys.joinWithCode,
                  icon: const Icon(Icons.login),
                  label: Text(l10n.joinWithCodeButton),
                  onPressed: () => context.pushNamed(AppRoute.joinByCode.name),
                ),
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noGroups),
              ),
            for (final group in list)
              ListTile(
                key: GroupKeys.groupTile(group.id),
                leading: CircleAvatar(
                  child: Text(group.name.characters.first.toUpperCase()),
                ),
                title: Text(group.name),
                subtitle: Text(
                  '${roleLabel(group.role, l10n)} · '
                  '${l10n.groupMyShare(shareLevelLabel(group.shareLevel, l10n))}',
                ),
                onTap: () => context.pushNamed(
                  AppRoute.group.name,
                  pathParameters: {'groupId': group.id},
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft = await GroupEditorScreen.show(context);
    if (draft == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final id = await ref
          .read(groupsServiceProvider)
          .create(name: draft.name, description: draft.description);
      messenger.showSnackBar(SnackBar(content: Text(l10n.groupCreated)));
      if (context.mounted) {
        await context.pushNamed(
          AppRoute.group.name,
          pathParameters: {'groupId': id},
        );
      }
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    }
  }
}

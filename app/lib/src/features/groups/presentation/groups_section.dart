/// Les groupes de l'utilisateur dans l'onglet Social : un appui ouvre le
/// groupe. Créer un groupe et en rejoindre un passent par le bouton
/// « Ajouter » de l'onglet, qui appelle [createGroup] et [joinGroupWithCode].
///
/// Choix non évident : chaque groupe reçoit une couleur de la palette tirée
/// de son identifiant ([paletteHexFor]) — stable, et sans réglage de plus :
/// les initiales seules se ressemblaient toutes.
library;

import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/common_widgets/section_title.dart';
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

/// Crée un groupe, puis l'ouvre.
Future<void> createGroup(BuildContext context, WidgetRef ref) async {
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

/// Ouvre « Rejoindre un groupe » (saisie du code).
Future<void> joinGroupWithCode(BuildContext context) =>
    context.pushNamed(AppRoute.joinByCode.name);

class GroupsSection extends ConsumerWidget {
  const GroupsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(myGroupsProvider);
    return Column(
      key: GroupKeys.listScreen,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.groupsTitle),
        ...switch (groups) {
          AsyncData(value: final list) when list.isEmpty => [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l10n.noGroups),
            ),
          ],
          AsyncData(value: final list) => [
            for (final group in list) _GroupTile(group: group),
          ],
          AsyncError(:final error) => [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(messageForError(error, l10n)),
            ),
          ],
          _ => const [
            Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        },
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final MyGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = colorFromHex(
      paletteHexFor(group.id),
      Theme.of(context).colorScheme.primary,
    );
    return ListTile(
      key: GroupKeys.groupTile(group.id),
      leading: CircleAvatar(
        backgroundColor: color,
        child: Text(
          group.name.characters.firstOrNull?.toUpperCase() ?? '',
          style: TextStyle(color: readableOn(color)),
        ),
      ),
      title: Text(group.name),
      subtitle: Text(
        '${roleLabel(group.role, l10n)} · '
        '${l10n.groupMyShare(shareLevelLabel(group.shareLevel, l10n))}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.pushNamed(
        AppRoute.group.name,
        pathParameters: {'groupId': group.id},
      ),
    );
  }
}

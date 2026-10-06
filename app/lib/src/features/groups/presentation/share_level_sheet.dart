/// « Ce que je partage avec ce groupe » : tout (titres et lieux), occupé
/// sans détail, ou rien. Ouvert depuis la puce « Je partage : … » de la
/// page du groupe, où ce réglage de vie privée se voit sans le chercher.
///
/// Choix non évident : le choix s'applique dès l'appui, et la feuille se
/// referme ; « Tout » rappelle que l'assistant IA d'un membre voit ce que
/// l'app lui montre.
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/groups/presentation/group_labels.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ouvre la feuille, puis enregistre le niveau choisi et en annonce l'issue.
Future<void> showShareLevelSheet(
  BuildContext context,
  WidgetRef ref,
  MyGroup group,
) async {
  final level = await showModalBottomSheet<ShareLevel>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ShareLevelSheet(current: group.shareLevel),
  );
  if (level == null || level == group.shareLevel || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    await ref.read(groupsServiceProvider).setMyShareLevel(group.id, level);
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareSaved)));
  } on Exception catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(messageForError(error, l10n))),
    );
  }
}

class _ShareLevelSheet extends StatelessWidget {
  const _ShareLevelSheet({required this.current});

  final ShareLevel current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.myShareLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<ShareLevel>(
            groupValue: current,
            onChanged: (level) => Navigator.of(context).pop(level),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final level in ShareLevel.values)
                  RadioListTile<ShareLevel>(
                    key: GroupKeys.myShare(level),
                    value: level,
                    title: Text(shareLevelLabel(level, l10n)),
                    // « Tout » vaut aussi pour l'assistant IA qu'un membre a
                    // branché : il voit ce que l'app lui montre.
                    subtitle: level == ShareLevel.details
                        ? Text(l10n.shareDetailsAssistantHint)
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

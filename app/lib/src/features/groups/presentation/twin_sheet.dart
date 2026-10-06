/// Le jumelage vu depuis l'écran d'un groupe : le bandeau « Ce groupe existe
/// aussi dans … » pour tous les membres ([TwinBanner]), et la feuille où les
/// admins lancent, relancent ou défont un jumelage ([showTwinSheet]).
///
/// Choix non évidents :
/// - le bandeau n'affiche qu'un jumeau complet : un jumeau en attente n'a
///   pas encore de code à rejoindre. Il se tait aussi si la lecture échoue
///   (l'erreur est journalisée par l'observateur des providers) : un
///   bandeau en panne ne doit pas masquer l'agenda ;
/// - l'adresse de l'autre app est reconstruite depuis sa base fixe et le
///   code validé (`TwinApp.joinUri`), jamais lue d'un lien reçu ;
/// - défaire supprime l'invitation donnée à l'autre app ; la confirmation
///   dit que l'autre app garde son bouton jusqu'à ce qu'on l'y retire ;
/// - rejoindre un cercle DewDrop n'est qu'une demande à son créateur
///   ([TwinApp.joinIsRequest]) : le bouton et l'explication le disent.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/application/twin_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/twin.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/groups/presentation/group_labels.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// « Ce groupe existe aussi dans … — Rejoindre », un par jumeau complet.
class TwinBanner extends ConsumerWidget {
  const TwinBanner({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final twins = ref.watch(groupTwinsProvider(groupId)).value ?? const [];
    return Column(
      children: [
        for (final twin in twins)
          if (twin.remoteCode case final code?)
            ListTile(
              dense: true,
              leading: const Icon(Icons.link),
              title: Text(l10n.twinAlsoIn(twin.app.displayName)),
              trailing: TextButton(
                key: GroupKeys.twinJoin(twin.app),
                onPressed: () => _join(context, ref, twin.app, code),
                child: Text(
                  twin.app.joinIsRequest
                      ? l10n.twinRequestJoinButton
                      : l10n.twinJoinButton,
                ),
              ),
            ),
      ],
    );
  }
}

Future<void> _join(
  BuildContext context,
  WidgetRef ref,
  TwinApp app,
  String code,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context).twinOpenFailed(app.displayName);
  if (!await ref.read(linkOpenerProvider).open(app.joinUri(code))) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Feuille de jumelage d'un groupe (admins).
Future<void> showTwinSheet(BuildContext context, MyGroup group) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TwinSheet(group: group),
    );

class _TwinSheet extends ConsumerStatefulWidget {
  const _TwinSheet({required this.group});

  final MyGroup group;

  @override
  ConsumerState<_TwinSheet> createState() => _TwinSheetState();
}

class _TwinSheetState extends ConsumerState<_TwinSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AsyncValueWidget<List<GroupTwin>>(
          value: ref.watch(groupTwinsProvider(widget.group.id)),
          // Deux apps jumelles : sur un petit téléphone, la feuille défile.
          data: (twins) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.twinTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final app in TwinApp.values) ...[
                  if (app != TwinApp.values.first) const Divider(height: 32),
                  const SizedBox(height: 8),
                  Text(
                    app.joinIsRequest
                        ? l10n.twinExplainRequest(app.displayName)
                        : l10n.twinExplain(app.displayName),
                  ),
                  const SizedBox(height: 16),
                  ..._actions(
                    app,
                    twins.where((t) => t.app == app).firstOrNull,
                    l10n,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(TwinApp app, GroupTwin? twin, AppLocalizations l10n) {
    final name = app.displayName;
    final unlink = twin == null
        ? null
        : TextButton(
            key: GroupKeys.twinUnlink(app),
            onPressed: _busy ? null : () => _unlink(twin),
            child: Text(l10n.twinUnlinkButton),
          );
    return switch (twin) {
      null => [
        FilledButton(
          key: GroupKeys.twinStart(app),
          onPressed: _busy ? null : () => _start(app),
          child: Text(l10n.twinStartButton(name)),
        ),
      ],
      GroupTwin(isPending: true) => [
        Text(l10n.twinPending(name)),
        const SizedBox(height: 8),
        FilledButton(
          key: GroupKeys.twinStart(app),
          onPressed: _busy ? null : () => _start(app),
          child: Text(l10n.twinRestartButton),
        ),
        ?unlink,
      ],
      GroupTwin() => [Text(l10n.twinLinked(name)), ?unlink],
    };
  }

  /// Lance (ou relance) le jumelage : ouvre la demande dans l'autre app.
  Future<void> _start(TwinApp app) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final request = await ref
          .read(twinServiceProvider)
          .start(widget.group, app);
      final opened = await ref.read(linkOpenerProvider).open(request);
      if (!opened) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.twinOpenFailed(app.displayName))),
        );
      }
      if (mounted) navigator.pop();
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink(GroupTwin twin) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = twin.app.displayName;
    final confirmed = await confirmAction(
      context,
      title: l10n.twinUnlinkTitle(name),
      body: l10n.twinUnlinkBody(name),
      action: l10n.twinUnlinkButton,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(twinServiceProvider).unlink(widget.group.id, twin);
      messenger.showSnackBar(SnackBar(content: Text(l10n.twinUnlinked)));
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

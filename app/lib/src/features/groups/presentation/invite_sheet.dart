/// Fenêtre d'invitation : le code en cours de l'utilisateur (créé s'il n'en
/// a pas), à copier, et le lien vers la version web quand le build en
/// connaît l'adresse. Le code se désactive d'un geste.
///
/// Choix non évident : on réutilise la dernière invitation encore valable
/// de l'utilisateur plutôt que d'en créer une à chaque ouverture — sinon
/// les codes actifs s'accumulent, et chacun ouvre le groupe.
library;

import 'package:agora/src/config/web_links.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

Future<void> showInviteSheet(BuildContext context, MyGroup group) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _InviteSheet(group: group, messenger: ScaffoldMessenger.of(context)),
    );

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.group, required this.messenger});

  final MyGroup group;

  /// Celui de l'écran du groupe : les confirmations survivent à la fenêtre.
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  late final Future<GroupInvite> _invite = ref
      .read(groupsServiceProvider)
      .currentInvite(widget.group.id);

  void _say(String message) =>
      widget.messenger.showSnackBar(SnackBar(content: Text(message)));

  Future<void> _copy(String text, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: text));
    _say(confirmation);
  }

  Future<void> _revoke(GroupInvite invite) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(groupsServiceProvider).revokeInvite(invite.code);
      _say(l10n.inviteRevoked);
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (error) {
      _say(messageForError(error, l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final base = ref.watch(webBaseUrlProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<GroupInvite>(
          future: _invite,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(messageForError(snapshot.error!, l10n));
            }
            final invite = snapshot.data;
            if (invite == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final until = DateFormat.yMMMMd(
              Localizations.localeOf(context).toString(),
            ).format(invite.expiresAt.toLocal());
            final link = base == null ? null : inviteLink(base, invite.code);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.inviteTitle(widget.group.name),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  invite.code,
                  key: GroupKeys.inviteCode,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    letterSpacing: 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.inviteCodeHint(until),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      key: GroupKeys.copyCode,
                      icon: const Icon(Icons.copy),
                      label: Text(l10n.copyCode),
                      onPressed: () => _copy(invite.code, l10n.codeCopied),
                    ),
                    if (link != null)
                      FilledButton.icon(
                        key: GroupKeys.copyLink,
                        icon: const Icon(Icons.link),
                        label: Text(l10n.copyLink),
                        onPressed: () => _copy('$link', l10n.linkCopied),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: GroupKeys.revokeInvite,
                  onPressed: () => _revoke(invite),
                  child: Text(l10n.revokeInvite),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

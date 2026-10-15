/// Fenêtre d'un lien de profil : son QR code, à montrer ou à scanner, et de
/// quoi le partager d'un geste (feuille de partage du téléphone), le copier
/// ou le supprimer.
///
/// Choix non évidents :
/// - le QR code est toujours sur fond blanc : en thème sombre, un code
///   inversé ne se scanne pas ;
/// - sans adresse web dans le build (développement), il n'y a pas de lien
///   à encoder : la fenêtre le dit plutôt que d'afficher un QR code faux.
library;

import 'package:agora/src/config/web_links.dart';
import 'package:agora/src/device/sharer.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/profile_link/application/profile_link_providers.dart';
import 'package:agora/src/features/profile_link/domain/profile_link.dart';
import 'package:agora/src/features/profile_link/presentation/profile_link_keys.dart';
import 'package:agora/src/features/profile_link/presentation/profile_link_labels.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> showProfileLinkSheet(BuildContext context, ProfileLink link) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _LinkSheet(link: link, messenger: ScaffoldMessenger.of(context)),
    );

class _LinkSheet extends ConsumerWidget {
  const _LinkSheet({required this.link, required this.messenger});

  final ProfileLink link;

  /// Celui de l'écran des liens : les confirmations survivent à la fenêtre.
  final ScaffoldMessengerState messenger;

  void _say(String message) =>
      messenger.showSnackBar(SnackBar(content: Text(message)));

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(profileLinkServiceProvider).revoke(link.code);
      _say(l10n.profileLinkRevoked);
      navigator.pop();
    } on Exception catch (error) {
      _say(messageForError(error, l10n));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final base = ref.watch(webBaseUrlProvider);
    final sharer = ref.watch(sharerProvider);
    final url = base == null ? null : profileLink(base, link.code);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(link.label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(levelLine(link.level, l10n), style: theme.textTheme.bodySmall),
            Text(
              calendarsLine(
                link,
                ref.watch(shareableCalendarsProvider).value ?? const [],
                l10n,
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (url == null)
              Text(l10n.profileLinkNoWebAddress)
            else ...[
              Center(
                child: QrImageView(
                  key: ProfileLinkKeys.qr,
                  data: '$url',
                  size: 200,
                  backgroundColor: Colors.white,
                  semanticsLabel: l10n.profileLinkQrLabel,
                ),
              ),
              const SizedBox(height: 8),
              // Le lien en toutes lettres : on peut le lire, le dicter ou le
              // sélectionner quand on ne peut pas scanner.
              SelectableText(
                '$url',
                key: ProfileLinkKeys.url,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (sharer.isAvailable)
                    FilledButton.icon(
                      key: ProfileLinkKeys.share,
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l10n.shareInviteButton),
                      onPressed: () => sharer.share(
                        l10n.profileLinkShareText('$url'),
                        subject: l10n.profileLinksTitle,
                      ),
                    ),
                  FilledButton.tonalIcon(
                    key: ProfileLinkKeys.copyLink,
                    icon: const Icon(Icons.link),
                    label: Text(l10n.copyLink),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: '$url'));
                      _say(l10n.linkCopied);
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              key: ProfileLinkKeys.revoke,
              onPressed: () => _revoke(context, ref),
              child: Text(l10n.profileLinkRevoke),
            ),
            Text(
              l10n.profileLinkRevokeHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

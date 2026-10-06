/// Ligne « Google » du profil (section Connexions) : relier son compte
/// Google à celui d'Agora pour se connecter avec, ou le délier.
///
/// Choix non évidents :
/// - la ligne n'existe que si le build propose Google
///   (`signInProvidersProvider`) : sans le fournisseur activé sur le
///   serveur, « Relier » mènerait à une page d'erreur ;
/// - « Relier » ouvre le navigateur et rend la main tout de suite ; le
///   compte relié n'apparaît qu'au retour, quand la session change
///   (`linkedAccountProvider` l'écoute) ;
/// - un compte ouvert par Google n'a pas d'autre moyen de connexion : pas
///   de « Délier », que GoTrue refuserait.
library;

import 'package:agora/src/config/sign_in_providers.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/domain/linked_account.dart';
import 'package:agora/src/features/auth/domain/social_provider.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _google = SocialProvider.google;

class GoogleAccountTile extends ConsumerStatefulWidget {
  const GoogleAccountTile({super.key});

  @override
  ConsumerState<GoogleAccountTile> createState() => _GoogleAccountTileState();
}

class _GoogleAccountTileState extends ConsumerState<GoogleAccountTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() => _run(() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final opened = await ref.read(authRepositoryProvider).linkAccount(_google);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.googleLinkFailed)));
    }
  });

  Future<void> _unlink() async {
    await _run(() => ref.read(authRepositoryProvider).unlinkAccount(_google));
    if (mounted) ref.invalidate(linkedAccountProvider(_google));
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(signInProvidersProvider).contains(_google)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(linkedAccountProvider(_google));
    return ListTile(
      key: AuthKeys.account(_google),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(l10n.googleSectionTitle),
      subtitle: Text(switch (account.value) {
        LinkedAccount(:final label, isOnlyWayIn: true) =>
          l10n.googleAccountOnlyWayIn(label),
        LinkedAccount(:final label) => l10n.googleAccountLinked(label),
        null => l10n.googleAccountNotLinked,
      }),
      trailing: switch (account) {
        AsyncValue(value: LinkedAccount(isOnlyWayIn: true)) => null,
        AsyncValue(value: LinkedAccount()) => TextButton(
          key: AuthKeys.unlinkAccount(_google),
          onPressed: _busy ? null : _unlink,
          child: Text(l10n.googleUnlinkButton),
        ),
        // Première lecture en cours : rien à proposer encore.
        AsyncLoading(hasValue: false) => const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        // Pas relié, ou lecture en échec : relier reste possible.
        _ => FilledButton.tonal(
          key: AuthKeys.linkAccount(_google),
          onPressed: _busy ? null : _link,
          child: Text(l10n.googleLinkButton),
        ),
      },
    );
  }
}

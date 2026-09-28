/// Section « Discord » du profil : relier ou délier son compte Discord, ce
/// qui permet au bot de répondre à `/agenda` et `/dispo`.
///
/// Choix non évident : « Relier » ouvre le navigateur et rend la main tout
/// de suite ; l'état relié n'apparaît qu'au retour, quand la session change
/// (`discordAccountProvider` l'écoute). Rien à attendre ici.
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/discord/application/discord_providers.dart';
import 'package:agora/src/features/discord/domain/discord.dart';
import 'package:agora/src/features/discord/presentation/discord_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscordAccountSection extends ConsumerStatefulWidget {
  const DiscordAccountSection({super.key});

  @override
  ConsumerState<DiscordAccountSection> createState() =>
      _DiscordAccountSectionState();
}

class _DiscordAccountSectionState extends ConsumerState<DiscordAccountSection> {
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
    final opened = await ref.read(discordServiceProvider).linkAccount();
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.discordLinkFailed)));
    }
  });

  Future<void> _unlink() async {
    await _run(() => ref.read(discordServiceProvider).unlinkAccount());
    ref.invalidate(discordAccountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(discordAccountProvider);
    return ListTile(
      key: DiscordKeys.account,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.forum_outlined),
      title: Text(l10n.discordSectionTitle),
      subtitle: Text(switch (account.value) {
        DiscordAccount(:final name) => l10n.discordAccountLinked(name),
        null => l10n.discordAccountNotLinked,
      }),
      trailing: switch (account) {
        AsyncValue(value: DiscordAccount()) => TextButton(
          key: DiscordKeys.unlinkAccount,
          onPressed: _busy ? null : _unlink,
          child: Text(l10n.discordUnlinkButton),
        ),
        // Première lecture en cours : rien à proposer encore.
        AsyncLoading(hasValue: false) => const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        // Pas relié, ou lecture en échec : relier reste possible.
        _ => FilledButton.tonal(
          key: DiscordKeys.linkAccount,
          onPressed: _busy ? null : _link,
          child: Text(l10n.discordLinkButton),
        ),
      },
    );
  }
}

/// Écran « Assistant IA » (profil → Assistant IA) : l'adresse à donner à un
/// assistant (claude.ai, Claude Code, ChatGPT…), et les accès accordés, à
/// retirer d'un geste.
///
/// Choix non évidents :
/// - autoriser un assistant se fait hors d'ici (l'assistant ouvre l'écran de
///   consentement de l'app web) : cet écran est donc le seul endroit où
///   l'utilisateur VOIT qui lit son agenda ;
/// - retirer un accès le coupe aussitôt : le serveur MCP fait juger chaque
///   jeton par GoTrue, qui ne connaît plus la session. L'écran le dit ;
/// - serveur OAuth éteint (`AssistantsUnavailableException`) : un état à
///   part, pas une erreur — c'est l'entre-deux d'une mise en ligne.
library;

import 'package:agora/src/config/web_links.dart';
import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/assistant/application/assistant_providers.dart';
import 'package:agora/src/features/assistant/domain/assistant.dart';
import 'package:agora/src/features/assistant/presentation/assistant_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Page publique qui décrit le serveur MCP, servie par la version web.
const assistantGuidePath = '/assistant.html';

class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  Future<void> _copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(l10n.assistantCopied)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final url = ref.watch(mcpUrlProvider);
    final web = ref.watch(webBaseUrlProvider);
    return Scaffold(
      key: AssistantKeys.screen,
      appBar: AppBar(title: Text(l10n.assistantTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.assistantIntro),
          const SizedBox(height: 16),
          if (url != null) ...[
            Text(l10n.assistantAddressTitle, style: text.titleSmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: SelectableText(url.toString(), key: AssistantKeys.address),
              trailing: IconButton(
                key: AssistantKeys.copyAddress,
                tooltip: l10n.assistantCopy,
                icon: const Icon(Icons.copy),
                onPressed: () => _copy(context, url.toString()),
              ),
            ),
            Text(l10n.assistantClaudeAi),
            const SizedBox(height: 12),
            Text(l10n.assistantClaudeCode),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: SelectableText(
                claudeCodeCommand(url),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              trailing: IconButton(
                key: AssistantKeys.copyCommand,
                tooltip: l10n.assistantCopy,
                icon: const Icon(Icons.copy),
                onPressed: () => _copy(context, claudeCodeCommand(url)),
              ),
            ),
            Text(l10n.assistantOthers),
            if (web != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: AssistantKeys.guide,
                  onPressed: () => ref
                      .read(linkOpenerProvider)
                      .open(web.resolve(assistantGuidePath)),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.assistantGuide),
                ),
              ),
          ] else
            Text(l10n.assistantNoAddress),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(l10n.assistantGrantsTitle, style: text.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.assistantRevokeImmediate, style: text.bodySmall),
          const SizedBox(height: 8),
          const _Grants(),
        ],
      ),
    );
  }
}

class _Grants extends ConsumerWidget {
  const _Grants();

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    AssistantGrant grant,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.assistantRevokeTitle),
        content: Text(l10n.assistantRevokeBody(_name(grant, l10n))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: AssistantKeys.confirmRevoke,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.assistantRevoke),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(assistantServiceProvider).revoke(grant.clientId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.assistantRevoked)));
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    }
  }

  static String _name(AssistantGrant grant, AppLocalizations l10n) =>
      grant.name.isEmpty ? l10n.assistantUnnamed : grant.name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return switch (ref.watch(assistantGrantsProvider)) {
      AsyncData(value: final grants) when grants.isEmpty => Text(
        l10n.assistantNoGrant,
        key: AssistantKeys.noGrant,
      ),
      AsyncData(value: final grants) => Column(
        children: [
          for (final grant in grants)
            ListTile(
              key: AssistantKeys.grant(grant.clientId),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smart_toy_outlined),
              title: Text(_name(grant, l10n)),
              subtitle: Text(
                l10n.assistantGrantedOn(
                  DateFormat.yMMMd(locale).format(grant.grantedAt.toLocal()),
                ),
              ),
              trailing: TextButton(
                key: AssistantKeys.revoke(grant.clientId),
                onPressed: () => _revoke(context, ref, grant),
                child: Text(l10n.assistantRevoke),
              ),
            ),
        ],
      ),
      AsyncError(error: AssistantsUnavailableException()) => Text(
        l10n.errorAssistantsUnavailable,
        key: AssistantKeys.unavailable,
      ),
      AsyncError(:final error) => Text(messageForError(error, l10n)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

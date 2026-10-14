/// Ouvrir le lien de profil de quelqu'un (`/profile/CODE`) : l'écran montre
/// de qui il s'agit, dit ce que va faire la copie, puis crée le proche et
/// l'ouvre.
///
/// Choix non évidents :
/// - l'écran consomme le lien retenu par le routeur pendant une connexion :
///   une fois ouvert, on n'y est plus ramené ;
/// - rien n'est copié avant l'appui sur « Créer le proche » : voir un aperçu
///   ne coûte rien à la personne dont on ouvre le lien ;
/// - un lien inconnu ou supprimé s'affiche comme une erreur, sans dire
///   lequel des deux.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/profile_link/application/profile_link_providers.dart';
import 'package:agora/src/features/profile_link/presentation/profile_link_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OpenProfileLinkScreen extends ConsumerStatefulWidget {
  const OpenProfileLinkScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<OpenProfileLinkScreen> createState() =>
      _OpenProfileLinkScreenState();
}

class _OpenProfileLinkScreenState extends ConsumerState<OpenProfileLinkScreen> {
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    ref.read(pendingProfileLinkProvider).code = null;
  }

  Future<void> _create(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _creating = true);
    try {
      final calendarId = await ref
          .read(profileLinkServiceProvider)
          .open(widget.code);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.openProfileDone(name))),
      );
      if (mounted) {
        context.goNamed(
          AppRoute.contact.name,
          pathParameters: {'calendarId': calendarId},
        );
      }
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      key: ProfileLinkKeys.openScreen,
      appBar: AppBar(title: Text(l10n.openProfileTitle)),
      body: AsyncValueWidget<String>(
        value: ref.watch(profileLinkNameProvider(widget.code)),
        data: (name) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.openProfileQuestion(name),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(l10n.openProfileBody(name)),
              const SizedBox(height: 24),
              SubmitButton(
                key: ProfileLinkKeys.openConfirm,
                label: l10n.openProfileConfirm,
                isLoading: _creating,
                onPressed: () => _create(name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

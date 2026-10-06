/// Onglet « Moi » de l'accueil : qui je suis (nom affiché, e-mail), mes
/// réglages (langue de l'app et des e-mails, fuseau horaire, mes agendas),
/// mes connexions (Google, Discord, assistants IA), puis la déconnexion, les
/// pages légales et, tout en bas, la suppression du compte.
///
/// Choix non évidents :
/// - chaque réglage s'applique **tout de suite** (pas de bouton
///   « Enregistrer » pour toute la page) : la langue, choisie dans un
///   dialogue, retraduit l'app aussitôt ; le nom se change dans un dialogue
///   qui le valide avant d'appeler le serveur ;
/// - le fuseau ne se tape pas : on reprend celui de l'appareil, et le
///   bouton ne s'affiche que s'il diffère de celui du profil. C'est le seul
///   réglage utile en pratique, et le serveur n'accepte de toute façon que
///   des identifiants IANA qu'il connaît ;
/// - « Supprimer mon compte » est loin de « Se déconnecter » : l'un se fait
///   tous les jours, l'autre jamais par mégarde ;
/// - les pages légales ne sont pas recopiées dans l'app : elles s'ouvrent
///   dans le navigateur, à l'adresse que donne aussi la fiche Play Store.
///   Sans adresse web dans le build (développement), elles disparaissent
///   plutôt que d'afficher des liens morts.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/section_title.dart';
import 'package:agora/src/config/web_links.dart';
import 'package:agora/src/device/device_timezone.dart';
import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/domain/credential_rules.dart';
import 'package:agora/src/features/auth/domain/left_behind_event.dart';
import 'package:agora/src/features/auth/presentation/google_account_tile.dart';
import 'package:agora/src/features/calendar/presentation/calendars_screen.dart';
import 'package:agora/src/features/discord/presentation/discord_account_section.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/features/profile/domain/profile.dart';
import 'package:agora/src/features/profile/presentation/profile_controller.dart';
import 'package:agora/src/features/profile/presentation/profile_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _maxContentWidth = 560.0;

/// Le fuseau de l'appareil, lu à l'affichage de l'onglet.
final _deviceTimezoneNameProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(deviceTimezoneProvider).current(),
);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    key: ProfileKeys.screen,
    body: AsyncValueWidget<Profile?>(
      value: ref.watch(currentProfileProvider),
      data: (profile) =>
          profile == null ? const SizedBox.shrink() : _MePage(profile),
    ),
  );
}

class _MePage extends ConsumerWidget {
  const _MePage(this.profile);

  final Profile profile;

  /// Enregistre [changed] et en annonce l'issue. La confirmation est relue
  /// dans la langue qu'on vient peut-être de choisir.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Profile changed,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final saved = await ref
        .read(profileControllerProvider.notifier)
        .save(changed);
    if (!saved) {
      final error = ref.read(profileControllerProvider).error;
      if (error is Exception) {
        messenger.showSnackBar(
          SnackBar(content: Text(messageForError(error, l10n))),
        );
      }
      return;
    }
    final confirmation = await AppLocalizations.delegate.load(
      Locale(changed.language.name),
    );
    messenger.showSnackBar(SnackBar(content: Text(confirmation.profileSaved)));
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: profile.displayName),
    );
    if (name == null || name == profile.displayName || !context.mounted) {
      return;
    }
    await _save(context, ref, profile.copyWith(displayName: name));
  }

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final language = await showDialog<AppLanguage>(
      context: context,
      builder: (_) => _LanguageDialog(current: profile.language),
    );
    if (language == null || language == profile.language || !context.mounted) {
      return;
    }
    await _save(context, ref, profile.copyWith(language: language));
  }

  /// Suppression du compte, après une confirmation qui en expose les
  /// conséquences. En cas de succès, la session se ferme et le routeur mène
  /// à la connexion ; le messager (celui de l'app) survit à l'écran et y
  /// affiche la confirmation.
  Future<void> _confirmDeletion(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Le dialogue rend « null » si l'on renonce, sinon un booléen : faut-il
    // effacer d'abord les rdv proposés aux groupes ?
    final alsoEvents = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (alsoEvents == null) return;
    final deleted = await ref
        .read(profileControllerProvider.notifier)
        .deleteAccount(alsoDeleteProposedEvents: alsoEvents);
    if (deleted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
      return;
    }
    final error = ref.read(profileControllerProvider).error;
    if (error is Exception) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    }
  }

  Future<void> _openLegal(
    BuildContext context,
    WidgetRef ref,
    LegalPage page,
    Uri base,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final opened = await ref
        .read(linkOpenerProvider)
        .open(legalLink(base, page));
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.legalLinkFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final webBaseUrl = ref.watch(webBaseUrlProvider);
    final isBusy = ref.watch(profileControllerProvider).isLoading;
    final email = ref.watch(currentUserProvider).value?.email;
    final deviceZone = ref.watch(_deviceTimezoneNameProvider).value;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        // Une colonne plutôt qu'une liste paresseuse : la page est courte,
        // et chaque ligne existe dès l'ouverture.
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Identity(
                profile: profile,
                email: email,
                onEdit: isBusy ? null : () => _editName(context, ref),
              ),
              const Divider(),
              SectionTitle(l10n.meSettingsTitle),
              ListTile(
                key: ProfileKeys.language,
                leading: const Icon(Icons.translate),
                title: Text(l10n.profileLanguageLabel),
                subtitle: Text(_languageName(profile.language, l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: isBusy ? null : () => _chooseLanguage(context, ref),
              ),
              ListTile(
                key: ProfileKeys.timezone,
                leading: const Icon(Icons.public),
                title: Text(l10n.profileTimezoneLabel),
                // Le bouton passe sous le fuseau, pas à droite : son libellé
                // ne tient pas à côté sur un téléphone.
                subtitle: deviceZone == null || deviceZone == profile.timezone
                    ? Text(
                        deviceZone == profile.timezone
                            ? l10n.timezoneMatchesDevice(profile.timezone)
                            : profile.timezone,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.timezone),
                          TextButton.icon(
                            key: ProfileKeys.useDeviceTimezone,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.my_location, size: 18),
                            label: Text(l10n.useDeviceTimezone),
                            onPressed: isBusy
                                ? null
                                : () => _save(
                                    context,
                                    ref,
                                    profile.copyWith(timezone: deviceZone),
                                  ),
                          ),
                        ],
                      ),
              ),
              ListTile(
                key: ProfileKeys.calendars,
                leading: const Icon(Icons.event_note_outlined),
                title: Text(l10n.calendarsTitle),
                subtitle: Text(l10n.calendarsTileSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => CalendarsScreen.show(context),
              ),
              SectionTitle(l10n.meConnectionsTitle),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: GoogleAccountTile(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DiscordAccountSection(),
              ),
              ListTile(
                key: ProfileKeys.assistant,
                leading: const Icon(Icons.smart_toy_outlined),
                title: Text(l10n.assistantTitle),
                subtitle: Text(l10n.assistantProfileSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(AppRoute.assistant.name),
              ),
              SectionTitle(l10n.meAccountTitle),
              ListTile(
                key: ProfileKeys.signOut,
                leading: const Icon(Icons.logout),
                title: Text(l10n.signOutButton),
                onTap: isBusy
                    ? null
                    : () => ref
                          .read(profileControllerProvider.notifier)
                          .signOut(),
              ),
              if (webBaseUrl != null)
                for (final (key, page, label) in [
                  (
                    ProfileKeys.legalPrivacy,
                    LegalPage.privacy,
                    l10n.legalPrivacy,
                  ),
                  (ProfileKeys.legalNotice, LegalPage.notice, l10n.legalNotice),
                  (ProfileKeys.legalTerms, LegalPage.terms, l10n.legalTerms),
                ])
                  ListTile(
                    key: key,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(label),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _openLegal(context, ref, page, webBaseUrl),
                  ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  key: ProfileKeys.deleteAccount,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: isBusy
                      ? null
                      : () => _confirmDeletion(context, ref),
                  child: Text(l10n.deleteAccountButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// En tête : l'initiale, le nom que voient les groupes, l'adresse du
/// compte, et le bouton qui change le nom.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.profile,
    required this.email,
    required this.onEdit,
  });

  final Profile profile;
  final String? email;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final address = email;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      leading: CircleAvatar(
        child: Text(
          profile.displayName.characters.firstOrNull?.toUpperCase() ?? '',
        ),
      ),
      title: Text(
        profile.displayName,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: address == null ? null : Text(address),
      trailing: IconButton(
        key: ProfileKeys.editName,
        tooltip: l10n.editNameTooltip,
        icon: const Icon(Icons.edit_outlined),
        onPressed: onEdit,
      ),
    );
  }
}

String _languageName(AppLanguage language, AppLocalizations l10n) =>
    switch (language) {
      AppLanguage.fr => l10n.languageFrench,
      AppLanguage.en => l10n.languageEnglish,
    };

/// Saisie du nom affiché : rend le nom validé, ou `null` si l'on renonce.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.displayNameLabel),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: ProfileKeys.displayName,
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(helperText: l10n.displayNameHelper),
          validator: (value) => isValidDisplayName(value ?? '')
              ? null
              : l10n.validationDisplayName,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: ProfileKeys.save,
          onPressed: _submit,
          child: Text(l10n.saveButton),
        ),
      ],
    );
  }
}

/// Choix de la langue : rend la langue choisie, ou `null` si l'on renonce.
class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog({required this.current});

  final AppLanguage current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SimpleDialog(
      title: Text(l10n.profileLanguageLabel),
      children: [
        RadioGroup<AppLanguage>(
          groupValue: current,
          onChanged: (language) => Navigator.of(context).pop(language),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final language in AppLanguage.values)
                RadioListTile<AppLanguage>(
                  key: ProfileKeys.languageOption(language),
                  value: language,
                  title: Text(_languageName(language, l10n)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirmation de suppression : rend `null` si l'on renonce, sinon `true`
/// ou `false` selon qu'il faut effacer d'abord les rdv proposés aux groupes.
/// Le bouton de confirmation porte la couleur d'erreur du thème, pour qu'on
/// ne le confonde pas avec une action ordinaire.
///
/// Les rdv qui resteraient sont annoncés ici, et non après coup : c'est le
/// seul moment où l'on peut encore les effacer — le compte supprimé, plus
/// personne n'en aurait le droit.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  /// Trois suffisent à reconnaître de quoi il s'agit ; au-delà, le nombre
  /// dit le reste sans faire défiler une liste dans un dialogue.
  static const _shown = 3;

  bool _alsoDeleteEvents = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    // En cours de lecture, on n'annonce rien plutôt qu'un chiffre faux.
    final leftBehind =
        ref.watch(proposedGroupEventsProvider).value ??
        const <LeftBehindEvent>[];
    return AlertDialog(
      title: Text(l10n.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountBody),
            if (leftBehind.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.deleteAccountLeftBehind),
              const SizedBox(height: 8),
              for (final event in leftBehind.take(_shown))
                Text(
                  l10n.deleteAccountLeftBehindItem(
                    event.title,
                    event.groupName,
                  ),
                ),
              if (leftBehind.length > _shown)
                Text(
                  l10n.deleteAccountLeftBehindMore(leftBehind.length - _shown),
                ),
              CheckboxListTile(
                key: ProfileKeys.alsoDeleteEvents,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _alsoDeleteEvents,
                onChanged: (value) =>
                    setState(() => _alsoDeleteEvents = value ?? false),
                title: Text(l10n.deleteAccountAlsoEvents),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: ProfileKeys.cancelDelete,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: ProfileKeys.confirmDelete,
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(_alsoDeleteEvents),
          child: Text(l10n.deleteAccountConfirm),
        ),
      ],
    );
  }
}

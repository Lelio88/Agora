/// Écran de profil : nom affiché, langue (app et e-mails), fuseau horaire,
/// pages légales, déconnexion et suppression du compte.
///
/// Le fuseau ne se tape pas : on reprend celui de l'appareil. C'est le seul
/// réglage utile en pratique, et le serveur n'accepte de toute façon que des
/// identifiants IANA qu'il connaît.
///
/// Les pages légales ne sont pas recopiées dans l'app : elles s'ouvrent dans
/// le navigateur, à l'adresse que donne aussi la fiche Play Store. Un seul
/// texte à tenir à jour. Sans adresse web dans le build (développement), la
/// section disparaît plutôt que d'afficher des liens morts.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/config/web_links.dart';
import 'package:agora/src/device/device_timezone.dart';
import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/domain/credential_rules.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/features/profile/domain/profile.dart';
import 'package:agora/src/features/profile/presentation/profile_controller.dart';
import 'package:agora/src/features/profile/presentation/profile_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _maxContentWidth = 560.0;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: ProfileKeys.screen,
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: AsyncValueWidget<Profile?>(
        value: ref.watch(currentProfileProvider),
        data: (profile) =>
            profile == null ? const SizedBox.shrink() : _ProfileForm(profile),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm(this.profile);

  final Profile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _displayName = TextEditingController(
    text: widget.profile.displayName,
  );
  late AppLanguage _language = widget.profile.language;
  late String _timezone = widget.profile.timezone;

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _useDeviceTimezone() async {
    final timezone = await ref.read(deviceTimezoneProvider).current();
    if (mounted) setState(() => _timezone = timezone);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await ref
        .read(profileControllerProvider.notifier)
        .save(
          widget.profile.copyWith(
            displayName: _displayName.text.trim(),
            language: _language,
            timezone: _timezone,
          ),
        );
    if (!saved || !mounted) return;
    // Texte relu après l'enregistrement : il suit la langue qu'on vient de
    // choisir.
    final confirmation = await AppLocalizations.delegate.load(
      Locale(_language.name),
    );
    messenger.showSnackBar(SnackBar(content: Text(confirmation.profileSaved)));
  }

  /// Suppression du compte, après une confirmation qui en expose les
  /// conséquences. En cas de succès, la session se ferme et le routeur mène
  /// à la connexion ; le messager (celui de l'app) survit à l'écran et y
  /// affiche la confirmation.
  Future<void> _confirmDeletion() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (confirmed != true) return;
    final deleted = await ref
        .read(profileControllerProvider.notifier)
        .deleteAccount();
    if (deleted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
    }
  }

  Future<void> _openLegal(LegalPage page, Uri base) async {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final webBaseUrl = ref.watch(webBaseUrlProvider);
    final controller = ref.watch(profileControllerProvider);
    final email = ref.watch(currentUserProvider).value?.email;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (email != null) Text(email, style: text.bodyLarge),
                const SizedBox(height: 16),
                TextFormField(
                  key: ProfileKeys.displayName,
                  controller: _displayName,
                  decoration: InputDecoration(
                    labelText: l10n.displayNameLabel,
                    helperText: l10n.displayNameHelper,
                  ),
                  validator: (value) => isValidDisplayName(value ?? '')
                      ? null
                      : l10n.validationDisplayName,
                ),
                const SizedBox(height: 24),
                Text(l10n.profileLanguageLabel, style: text.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<AppLanguage>(
                  key: ProfileKeys.language,
                  segments: [
                    ButtonSegment(
                      value: AppLanguage.fr,
                      label: Text(l10n.languageFrench),
                    ),
                    ButtonSegment(
                      value: AppLanguage.en,
                      label: Text(l10n.languageEnglish),
                    ),
                  ],
                  selected: {_language},
                  onSelectionChanged: (selection) =>
                      setState(() => _language = selection.first),
                ),
                const SizedBox(height: 24),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.profileTimezoneLabel,
                  ),
                  child: Text(_timezone),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: ProfileKeys.useDeviceTimezone,
                    onPressed: _useDeviceTimezone,
                    icon: const Icon(Icons.my_location),
                    label: Text(l10n.useDeviceTimezone),
                  ),
                ),
                if (controller.error case final error?)
                  FormErrorText(messageForError(error, l10n)),
                const SizedBox(height: 16),
                SubmitButton(
                  key: ProfileKeys.save,
                  label: l10n.saveButton,
                  isLoading: controller.isLoading,
                  onPressed: _save,
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: ProfileKeys.signOut,
                  onPressed: controller.isLoading
                      ? null
                      : () => ref
                            .read(profileControllerProvider.notifier)
                            .signOut(),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.signOutButton),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: ProfileKeys.deleteAccount,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: controller.isLoading ? null : _confirmDeletion,
                  child: Text(l10n.deleteAccountButton),
                ),
                if (webBaseUrl != null) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(l10n.legalSectionTitle, style: text.labelLarge),
                  const SizedBox(height: 4),
                  _LegalLink(
                    buttonKey: ProfileKeys.legalPrivacy,
                    label: l10n.legalPrivacy,
                    onPressed: () => _openLegal(LegalPage.privacy, webBaseUrl),
                  ),
                  _LegalLink(
                    buttonKey: ProfileKeys.legalNotice,
                    label: l10n.legalNotice,
                    onPressed: () => _openLegal(LegalPage.notice, webBaseUrl),
                  ),
                  _LegalLink(
                    buttonKey: ProfileKeys.legalTerms,
                    label: l10n.legalTerms,
                    onPressed: () => _openLegal(LegalPage.terms, webBaseUrl),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lien vers une page légale : discret, aligné à gauche, avec l'icône qui
/// annonce une sortie de l'app.
///
/// La clé va sur le BOUTON, pas sur l'alignement qui l'entoure : ce dernier
/// occupe toute la largeur, et un appui visé en son centre tomberait à côté
/// du bouton dès que le libellé est court.
class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(label),
    ),
  );
}

/// Confirmation de suppression : renvoie `true` si l'on confirme. Le bouton
/// de confirmation porte la couleur d'erreur du thème, pour qu'on ne le
/// confonde pas avec une action ordinaire.
class _DeleteAccountDialog extends StatelessWidget {
  const _DeleteAccountDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.deleteAccountTitle),
      content: Text(l10n.deleteAccountBody),
      actions: [
        TextButton(
          key: ProfileKeys.cancelDelete,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: ProfileKeys.confirmDelete,
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.deleteAccountConfirm),
        ),
      ],
    );
  }
}

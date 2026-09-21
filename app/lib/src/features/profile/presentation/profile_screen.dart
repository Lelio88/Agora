/// Écran de profil : nom affiché, langue (app et e-mails), fuseau horaire,
/// déconnexion.
///
/// Le fuseau ne se tape pas : on reprend celui de l'appareil. C'est le seul
/// réglage utile en pratique, et le serveur n'accepte de toute façon que des
/// identifiants IANA qu'il connaît.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/device/device_timezone.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

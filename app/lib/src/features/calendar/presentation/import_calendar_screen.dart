/// Import d'un agenda par son lien iCal : nom, lien, couleur, et où trouver
/// ce lien chez Google, Outlook et Apple. Comme les autres éditeurs, il ne
/// parle pas au serveur : il renvoie un [ImportedCalendarDraft] à « Mes
/// agendas ».
///
/// Choix non évidents :
/// - le lien est un secret (il ouvre tout l'agenda d'origine) : le champ
///   n'est jamais prérempli, et l'app ne le montre plus une fois l'agenda
///   importé ;
/// - le contrôle de saisie n'est qu'une aide (schéma, espaces, longueur) :
///   le serveur fait foi et refuse le reste (`InvalidFeedUrlException`).
library;

import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/color_picker.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

const _maxNameLength = 60;

class ImportCalendarScreen extends StatefulWidget {
  const ImportCalendarScreen({super.key});

  static Future<ImportedCalendarDraft?> show(BuildContext context) =>
      Navigator.of(context).push<ImportedCalendarDraft>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const ImportCalendarScreen(),
        ),
      );

  @override
  State<ImportCalendarScreen> createState() => _ImportCalendarScreenState();
}

class _ImportCalendarScreenState extends State<ImportCalendarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  String _colorHex = appPalette[1];

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      ImportedCalendarDraft(
        name: _name.text.trim(),
        url: _url.text.trim(),
        colorHex: _colorHex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: CalendarKeys.importScreen,
      appBar: AppBar(title: Text(l10n.importCalendarTitle)),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: CalendarKeys.importUrl,
                controller: _url,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.importUrlLabel,
                  hintText: 'https://…/basic.ics',
                ),
                validator: (value) => looksLikeFeedUrl(value ?? '')
                    ? null
                    : l10n.validationFeedUrl,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.importUrlPrivacy,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: CalendarKeys.importName,
                controller: _name,
                decoration: InputDecoration(labelText: l10n.calendarNameLabel),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  return trimmed.isEmpty || trimmed.length > _maxNameLength
                      ? l10n.validationCalendarName
                      : null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.calendarColorLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ColorPicker(
                selected: _colorHex,
                onSelected: (hex) => setState(() => _colorHex = hex),
              ),
              const SizedBox(height: 24),
              SubmitButton(
                key: CalendarKeys.importSave,
                label: l10n.importCalendarButton,
                isLoading: false,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              const _WhereToFindTheLink(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Où trouver le lien iCal d'un agenda chez les principaux fournisseurs.
class _WhereToFindTheLink extends StatelessWidget {
  const _WhereToFindTheLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    Widget provider(String name, String steps) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(steps, style: textTheme.bodyMedium),
        ],
      ),
    );
    return ExpansionTile(
      key: CalendarKeys.importHelp,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: const Icon(Icons.help_outline),
      title: Text(l10n.importHelpTitle),
      children: [
        provider('Google Agenda', l10n.importHelpGoogle),
        provider('Outlook', l10n.importHelpOutlook),
        provider('Apple (iCloud)', l10n.importHelpApple),
        Text(l10n.importHelpRefresh, style: textTheme.bodySmall),
      ],
    );
  }
}

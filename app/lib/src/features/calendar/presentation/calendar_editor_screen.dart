/// Éditeur d'un agenda : nom, couleur, et ce que voient les membres de ses
/// groupes. Comme l'éditeur de rdv, il ne parle pas au serveur : il renvoie
/// un [CalendarEditorResult] à « Mes agendas », qui confirme une
/// suppression et appelle le service.
///
/// Pour un agenda importé, il montre aussi l'état de la synchro et propose
/// de la relancer — jamais le lien, que l'app ne connaît pas.
library;

import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/color_picker.dart';
import 'package:agora/src/features/calendar/presentation/feed_sync_labels.dart';
import 'package:agora/src/features/calendar/presentation/visibility_field.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

const _maxNameLength = 60;

sealed class CalendarEditorResult {
  const CalendarEditorResult();
}

final class CalendarEditorSaved extends CalendarEditorResult {
  const CalendarEditorSaved(this.draft);
  final CalendarDraft draft;
}

final class CalendarEditorDeleteRequested extends CalendarEditorResult {
  const CalendarEditorDeleteRequested();
}

/// Relancer la synchro d'un agenda importé.
final class CalendarEditorSyncRequested extends CalendarEditorResult {
  const CalendarEditorSyncRequested();
}

class CalendarEditorScreen extends StatefulWidget {
  const CalendarEditorScreen({
    this.existing,
    this.canDelete = false,
    super.key,
  });

  /// Agenda modifié ; `null` pour une création.
  final UserCalendar? existing;

  /// Faux pour le dernier agenda natif, qui ne se supprime pas.
  final bool canDelete;

  static Future<CalendarEditorResult?> show(
    BuildContext context, {
    UserCalendar? existing,
    bool canDelete = false,
  }) => Navigator.of(context).push<CalendarEditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          CalendarEditorScreen(existing: existing, canDelete: canDelete),
    ),
  );

  @override
  State<CalendarEditorScreen> createState() => _CalendarEditorScreenState();
}

class _CalendarEditorScreenState extends State<CalendarEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late String? _colorHex =
      widget.existing?.colorHex ??
      (widget.existing == null ? appPalette.first : null);
  late EventVisibility? _visibility = widget.existing?.visibility;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CalendarEditorSaved(
        CalendarDraft(
          name: _name.text,
          colorHex: _colorHex,
          visibility: _visibility,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final existing = widget.existing;
    return Scaffold(
      key: CalendarKeys.calendarEditor,
      appBar: AppBar(
        title: Text(
          existing == null ? l10n.newCalendarTitle : l10n.editCalendarTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: CalendarKeys.calendarName,
                controller: _name,
                autofocus: existing == null,
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
              const SizedBox(height: 8),
              VisibilityField(
                key: CalendarKeys.calendarVisibility,
                value: _visibility,
                onChanged: (value) => setState(() => _visibility = value),
              ),
              if (existing != null && existing.isImported)
                _SyncSection(calendar: existing),
              const SizedBox(height: 24),
              SubmitButton(
                key: CalendarKeys.calendarSave,
                label: l10n.saveButton,
                isLoading: false,
                onPressed: _submit,
              ),
              if (existing != null) ...[
                const SizedBox(height: 16),
                if (widget.canDelete)
                  TextButton.icon(
                    key: CalendarKeys.calendarDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.deleteCalendarButton),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(const CalendarEditorDeleteRequested()),
                  )
                else
                  Text(
                    l10n.lastCalendarHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// État de la synchro d'un agenda importé, et le bouton qui la relance.
class _SyncSection extends StatelessWidget {
  const _SyncSection({required this.calendar});

  final UserCalendar calendar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final failed = calendar.syncError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(failed ? Icons.sync_problem : Icons.sync),
          title: Text(l10n.importedCalendarLabel),
          subtitle: Text(
            syncStatusLabel(calendar, l10n, locale),
            style: failed
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
        ),
        OutlinedButton.icon(
          key: CalendarKeys.calendarSyncNow,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.syncNowButton),
          onPressed: () =>
              Navigator.of(context).pop(const CalendarEditorSyncRequested()),
        ),
      ],
    );
  }
}

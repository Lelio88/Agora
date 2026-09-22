/// Éditeur d'un agenda : nom, couleur, et ce que voient les membres de ses
/// groupes. Comme l'éditeur de rdv, il ne parle pas au serveur : il renvoie
/// un [CalendarEditorResult] à « Mes agendas », qui confirme une
/// suppression et appelle le service.
library;

import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
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
              _ColorPicker(
                selected: _colorHex,
                onSelected: (hex) => setState(() => _colorHex = hex),
              ),
              const SizedBox(height: 8),
              VisibilityField(
                key: CalendarKeys.calendarVisibility,
                value: _visibility,
                onChanged: (value) => setState(() => _visibility = value),
              ),
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

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final fallback = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final hex in appPalette)
          Semantics(
            selected: hex == selected,
            button: true,
            child: InkWell(
              key: CalendarKeys.calendarColor(hex),
              customBorder: const CircleBorder(),
              onTap: () => onSelected(hex),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorFromHex(hex, fallback),
                child: hex == selected
                    ? Icon(
                        Icons.check,
                        color: readableOn(colorFromHex(hex, fallback)),
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

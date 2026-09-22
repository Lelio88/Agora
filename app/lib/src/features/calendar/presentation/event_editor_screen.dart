/// Éditeur d'un rdv : création, ou modification d'une instance de l'agenda.
///
/// Il ne parle pas au serveur lui-même : il renvoie un [EditorResult] à
/// l'écran d'agenda, qui pose la question « cette occurrence ou la série »
/// s'il y a lieu, puis appelle le service. L'éditeur reste ainsi testable
/// seul, et la question de portée n'existe qu'à un endroit.
///
/// Dates et heures sont saisies dans le fuseau local de l'appareil et
/// stockées en UTC ; un rdv « journée entière » va de minuit UTC à minuit
/// UTC (fin exclue), sur sa date locale. L'éditeur en montre le dernier jour
/// inclus, relu par [AgendaItem.localEnd] et jamais par `toLocal()`.
library;

import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/visibility_field.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _maxTitleLength = 200;
const _defaultDuration = Duration(hours: 1);

sealed class EditorResult {
  const EditorResult();
}

final class EditorSaved extends EditorResult {
  const EditorSaved(this.draft);
  final EventDraft draft;
}

final class EditorDeleteRequested extends EditorResult {
  const EditorDeleteRequested();
}

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({
    required this.calendarId,
    required this.timezone,
    this.calendars = const [],
    this.existing,
    this.initialStart,
    super.key,
  });

  /// Agenda proposé (celui du rdv modifié, ou l'agenda par défaut).
  final String calendarId;

  /// Agendas où ranger le rdv ; le choix n'apparaît qu'à partir de deux.
  final List<UserCalendar> calendars;

  /// Fuseau de répétition de la série (celui du profil).
  final String timezone;

  /// Instance modifiée ; `null` pour une création.
  final AgendaItem? existing;

  /// Début proposé à la création (créneau touché dans l'agenda).
  final DateTime? initialStart;

  /// Ouvre l'éditeur et renvoie ce que l'utilisateur a décidé, ou `null`.
  static Future<EditorResult?> show(
    BuildContext context, {
    required String calendarId,
    required String timezone,
    List<UserCalendar> calendars = const [],
    AgendaItem? existing,
    DateTime? initialStart,
  }) => Navigator.of(context).push<EditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EventEditorScreen(
        calendarId: calendarId,
        timezone: timezone,
        calendars: calendars,
        existing: existing,
        initialStart: initialStart,
      ),
    ),
  );

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _location = TextEditingController(text: widget.existing?.location);
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late DateTime _start;
  late DateTime _end;
  late bool _isAllDay = widget.existing?.isAllDay ?? false;
  late EventVisibility? _visibility = widget.existing?.visibility;
  late String _calendarId = widget.existing?.calendarId ?? widget.calendarId;

  /// Règle éditable ; `null` sans répétition. Une règle importée hors du
  /// sous-ensemble éditable est gardée telle quelle dans [_advancedRule].
  late RecurrenceRule? _recurrence;
  late final String? _advancedRule;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _start = existing.localStart;
      // L'éditeur montre le dernier jour d'une journée entière (inclus),
      // le stockage sa fin exclue : on recule d'un jour de calendrier (pas
      // de 24 h, faux les jours de changement d'heure).
      final end = existing.localEnd;
      _end = existing.isAllDay
          ? DateTime(end.year, end.month, end.day - 1)
          : end;
      _recurrence = existing.rrule == null
          ? null
          : RecurrenceRule.parse(existing.rrule!);
      _advancedRule = existing.rrule != null && _recurrence == null
          ? existing.rrule
          : null;
    } else {
      _start = _roundedStart(widget.initialStart?.toLocal() ?? DateTime.now());
      _end = _start.add(_defaultDuration);
      _recurrence = null;
      _advancedRule = null;
    }
  }

  static DateTime _roundedStart(DateTime value) {
    final minutes = (value.minute / 30).ceil() * 30;
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
    ).add(Duration(minutes: minutes));
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_start);
    if (picked == null) return;
    setState(() {
      final duration = _end.difference(_start);
      _start = picked;
      _end = picked.add(duration);
    });
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_end);
    if (picked == null) return;
    setState(() => _end = picked);
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 10),
    );
    if (date == null || !mounted) return null;
    if (_isAllDay) return DateTime(date.year, date.month, date.day);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final isFormValid = _formKey.currentState?.validate() ?? false;
    final rangeError = _end.isAfter(_start) || _isAllDay
        ? null
        : l10n.validationEndBeforeStart;
    setState(() => _rangeError = rangeError);
    if (!isFormValid || rangeError != null) return;

    final (start, end) = _isAllDay
        ? (
            _allDayUtc(_start),
            _allDayUtc(_end.isBefore(_start) ? _start : _end)
                .add(const Duration(days: 1)),
          )
        : (_start.toUtc(), _end.toUtc());
    Navigator.of(context).pop(
      EditorSaved(
        EventDraft(
          calendarId: _calendarId,
          title: _title.text,
          location: _location.text,
          description: _description.text,
          start: start,
          end: end,
          isAllDay: _isAllDay,
          timezone: widget.existing?.timezone ?? widget.timezone,
          recurrence: _recurrence,
          visibility: _visibility,
        ).withRawRule(_advancedRule),
      ),
    );
  }

  static DateTime _allDayUtc(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMEd(locale);
    final timeFormat = DateFormat.Hm(locale);
    String when(DateTime value) => _isAllDay
        ? dateFormat.format(value)
        : '${dateFormat.format(value)} · ${timeFormat.format(value)}';
    final isEditing = widget.existing != null;
    return Scaffold(
      key: CalendarKeys.editor,
      appBar: AppBar(
        title: Text(isEditing ? l10n.editEventTitle : l10n.newEventTitle),
        actions: [
          if (isEditing)
            IconButton(
              key: CalendarKeys.delete,
              tooltip: l10n.deleteEventButton,
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  Navigator.of(context).pop(const EditorDeleteRequested()),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        // Colonne défilante plutôt qu'une ListView : tous les champs
        // existent dès l'ouverture, et le bouton du bas reste atteignable.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: CalendarKeys.title,
                controller: _title,
                autofocus: !isEditing,
                decoration: InputDecoration(labelText: l10n.eventTitleLabel),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  return trimmed.isEmpty || trimmed.length > _maxTitleLength
                      ? l10n.validationTitle
                      : null;
                },
              ),
              if (widget.calendars.length > 1) ...[
                const SizedBox(height: 8),
                _CalendarField(
                  calendars: widget.calendars,
                  value: _calendarId,
                  onChanged: (id) => setState(() => _calendarId = id),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                key: CalendarKeys.allDay,
                title: Text(l10n.allDayLabel),
                value: _isAllDay,
                onChanged: (value) => setState(() => _isAllDay = value),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(l10n.startsLabel),
                subtitle: Text(when(_start)),
                onTap: _pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(l10n.endsLabel),
                subtitle: Text(when(_end)),
                onTap: _pickEnd,
              ),
              if (_rangeError case final error?) FormErrorText(error),
              _RepeatField(
                recurrence: _recurrence,
                advancedRule: _advancedRule,
                onChanged: (rule) => setState(() => _recurrence = rule),
              ),
              VisibilityField(
                key: CalendarKeys.visibility,
                value: _visibility,
                onChanged: (value) => setState(() => _visibility = value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: CalendarKeys.location,
                controller: _location,
                decoration: InputDecoration(
                  labelText: l10n.eventLocationLabel,
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: CalendarKeys.description,
                controller: _description,
                decoration: InputDecoration(
                  labelText: l10n.eventDescriptionLabel,
                  prefixIcon: const Icon(Icons.notes),
                ),
                minLines: 2,
                maxLines: 6,
              ),
              const SizedBox(height: 24),
              SubmitButton(
                key: CalendarKeys.save,
                label: l10n.saveButton,
                isLoading: false,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu de répétition : jamais, ou une fréquence simple. Une règle avancée
/// importée s'affiche verrouillée : on ne la réécrit pas depuis l'app.
class _RepeatField extends StatelessWidget {
  const _RepeatField({
    required this.recurrence,
    required this.advancedRule,
    required this.onChanged,
  });

  final RecurrenceRule? recurrence;
  final String? advancedRule;
  final ValueChanged<RecurrenceRule?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (advancedRule != null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.repeat),
        title: Text(l10n.repeatLabel),
        subtitle: Text(l10n.repeatAdvanced),
      );
    }
    String label(Frequency? frequency) => switch (frequency) {
      null => l10n.repeatNever,
      Frequency.daily => l10n.repeatDaily,
      Frequency.weekly => l10n.repeatWeekly,
      Frequency.monthly => l10n.repeatMonthly,
      Frequency.yearly => l10n.repeatYearly,
    };
    return PopupMenuButton<Frequency?>(
      key: CalendarKeys.repeat,
      onSelected: (frequency) => onChanged(
        frequency == null ? null : RecurrenceRule(frequency: frequency),
      ),
      itemBuilder: (context) => [
        for (final frequency in [null, ...Frequency.values])
          PopupMenuItem<Frequency?>(
            key: CalendarKeys.repeatOption(frequency),
            value: frequency,
            child: Text(label(frequency)),
          ),
      ],
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.repeat),
        title: Text(l10n.repeatLabel),
        subtitle: Text(label(recurrence?.frequency)),
        trailing: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}

/// Visibilité du rdv pour les groupes : hérite, occupé ou invisible. On ne
/// peut que restreindre, jamais forcer le détail.

class _CalendarField extends StatelessWidget {
  const _CalendarField({
    required this.calendars,
    required this.value,
    required this.onChanged,
  });

  final List<UserCalendar> calendars;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final fallback = Theme.of(context).colorScheme.primary;
    return DropdownButtonFormField<String>(
      key: CalendarKeys.eventCalendar,
      initialValue: calendars.any((c) => c.id == value) ? value : null,
      // Largeur bornée : sans elle, le nom (Flexible) n'a pas de limite.
      isExpanded: true,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).eventCalendarLabel,
      ),
      items: [
        for (final calendar in calendars)
          DropdownMenuItem(
            key: CalendarKeys.eventCalendarOption(calendar.id),
            value: calendar.id,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 6,
                  backgroundColor: colorFromHex(calendar.colorHex, fallback),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(calendar.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: (id) {
        if (id != null) onChanged(id);
      },
    );
  }
}

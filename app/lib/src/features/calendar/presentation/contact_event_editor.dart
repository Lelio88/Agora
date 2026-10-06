/// Formulaires courts de l'agenda d'un proche : un anniversaire (un titre
/// et une date), des horaires de travail (les jours et les heures), un congé
/// (un jour ou une période). Ils ne demandent que ce que chaque sorte de rdv
/// laisse choisir, et rendent le même [EditorResult] que l'éditeur complet :
/// `event_actions.dart` et la page du proche s'en servent de la même façon.
///
/// Choix non évidents :
/// - un anniversaire est une journée entière répétée chaque année, un congé
///   une ou plusieurs journées entières sans répétition : ni interrupteur
///   « journée entière », ni menu de répétition, ni lieu, ni notes ;
/// - les horaires de travail se répètent chaque semaine, les jours cochés ;
///   les jours non cochés sont ses repos (la page du proche les en déduit).
///   Une fin avant le début est le lendemain : un horaire de nuit ;
/// - à la création, la série commence au premier jour coché à partir du
///   jour choisi : un premier jour hors de la règle ne serait pas une
///   occurrence. En modification, le jour reste celui de l'occurrence
///   ouverte, et seul l'écart d'heure se reporte sur la série ;
/// - les dates se saisissent en heure locale ; une journée entière est
///   stockée de minuit UTC à minuit UTC (fin exclue), comme dans l'éditeur
///   complet.
///
/// Invariant : n'ouvre que des rdv que [contactFormFor] lui confie, c'est-
/// à-dire dont il sait tout montrer ; rien ne s'y perd.
library;

import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/contact_agenda.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/event_editor_screen.dart';
import 'package:agora/src/features/calendar/presentation/weekday_chips.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _maxTitleLength = 200;

/// Horaires proposés à la création : du lundi au vendredi, 9 h–17 h.
const _defaultWorkDays = {
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
};
const _defaultWorkStart = TimeOfDay(hour: 9, minute: 0);
const _defaultWorkEnd = TimeOfDay(hour: 17, minute: 0);

class ContactEventEditor extends StatefulWidget {
  const ContactEventEditor({
    required this.kind,
    required this.calendarId,
    required this.timezone,
    this.existing,
    this.initialTitle,
    super.key,
  });

  final ContactEventKind kind;

  /// Agenda du proche.
  final String calendarId;

  /// Fuseau de répétition (celui du profil) ; celui du rdv en modification.
  final String timezone;

  /// Instance modifiée ; `null` pour une création.
  final AgendaItem? existing;

  /// Titre proposé à la création.
  final String? initialTitle;

  /// Ouvre le formulaire et renvoie ce que l'utilisateur a décidé, ou
  /// `null`.
  static Future<EditorResult?> show(
    BuildContext context, {
    required ContactEventKind kind,
    required String calendarId,
    required String timezone,
    AgendaItem? existing,
    String? initialTitle,
  }) => Navigator.of(context).push<EditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ContactEventEditor(
        kind: kind,
        calendarId: calendarId,
        timezone: timezone,
        existing: existing,
        initialTitle: initialTitle,
      ),
    ),
  );

  @override
  State<ContactEventEditor> createState() => _ContactEventEditorState();
}

class _ContactEventEditorState extends State<ContactEventEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.existing?.title ?? widget.initialTitle,
  );
  late final _location = TextEditingController(text: widget.existing?.location);

  /// Jour choisi : la date d'un anniversaire, le premier jour d'un congé,
  /// le jour de départ des horaires de travail.
  late DateTime _day;

  /// Dernier jour d'un congé (inclus).
  late DateTime _lastDay;

  late TimeOfDay _workStart;
  late TimeOfDay _workEnd;
  late Set<int> _workDays;

  /// Fin des horaires de travail (instant UTC, comme `RecurrenceRule`).
  DateTime? _until;
  String? _workError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final today = _date(DateTime.now());
    if (existing == null) {
      _day = today;
      _lastDay = today;
      _workStart = _defaultWorkStart;
      _workEnd = _defaultWorkEnd;
      _workDays = {..._defaultWorkDays};
      return;
    }
    final start = existing.localStart;
    final end = existing.localEnd;
    _day = _date(start);
    // Fin exclue d'une journée entière : on montre son dernier jour.
    _lastDay = existing.isAllDay
        ? DateTime(end.year, end.month, end.day - 1)
        : _date(end);
    _workStart = TimeOfDay.fromDateTime(start);
    _workEnd = TimeOfDay.fromDateTime(end);
    final rule = existing.rrule == null
        ? null
        : RecurrenceRule.parse(existing.rrule!);
    _workDays = rule == null || rule.weekdays.isEmpty
        ? {start.weekday}
        : {...rule.weekdays};
    _until = rule?.until;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  static DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _allDayUtc(DateTime local) =>
      DateTime.utc(local.year, local.month, local.day);

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        // Un anniversaire se note aussi à sa vraie date de naissance.
        firstDate: first ?? DateTime(1900),
        lastDate: DateTime(initial.year + 10),
      );

  Future<void> _pickDay() async {
    final picked = await _pickDate(_day);
    if (picked == null) return;
    setState(() {
      _day = picked;
      if (_lastDay.isBefore(picked)) _lastDay = picked;
      // Une fin d'horaires désormais avant le départ ne vaut plus rien.
      if (_until?.toLocal().isBefore(picked) ?? false) _until = null;
    });
  }

  Future<void> _pickLastDay() async {
    final picked = await _pickDate(
      _lastDay.isBefore(_day) ? _day : _lastDay,
      first: _day,
    );
    if (picked != null) setState(() => _lastDay = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _workStart : _workEnd,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _workStart = picked;
      } else {
        _workEnd = picked;
      }
      _workError = null;
    });
  }

  Future<void> _pickUntil() async {
    final current = _until?.toLocal();
    final picked = await _pickDate(
      current == null || current.isBefore(_day) ? _day : current,
      first: _day,
    );
    if (picked == null) return;
    // Fin incluse : jusqu'au dernier instant de ce jour, à l'heure locale.
    setState(
      () => _until = DateTime(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
        59,
      ).toUtc(),
    );
  }

  void _toggleDay(int weekday) {
    final days = {..._workDays};
    if (!days.remove(weekday)) days.add(weekday);
    // Au moins un jour travaillé : sans jour, il n'y a plus d'horaires.
    if (days.isNotEmpty) setState(() => _workDays = days);
  }

  /// Le premier jour coché à partir de [from].
  DateTime _firstWorkDay(DateTime from) {
    var day = from;
    while (!_workDays.contains(day.weekday)) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return day;
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final isFormValid = _formKey.currentState?.validate() ?? false;
    final isWork = widget.kind == ContactEventKind.workHours;
    final sameTime =
        isWork &&
        _workStart.hour == _workEnd.hour &&
        _workStart.minute == _workEnd.minute;
    // Une série qui finit avant son premier jour ne se déplierait pas : les
    // horaires disparaîtraient sans un mot.
    final until = _until;
    final endsTooSoon =
        isWork &&
        !_isEditing &&
        until != null &&
        until.isBefore(_firstWorkDay(_day));
    setState(
      () => _workError = sameTime
          ? l10n.validationWorkHours
          : endsTooSoon
          ? l10n.validationWorkUntil
          : null,
    );
    if (!isFormValid || sameTime || endsTooSoon) return;
    Navigator.of(context).pop(EditorSaved(_draft()));
  }

  EventDraft _draft() {
    final timezone = widget.existing?.timezone ?? widget.timezone;
    final title = _title.text;
    switch (widget.kind) {
      case ContactEventKind.birthday:
        final start = _allDayUtc(_day);
        return EventDraft(
          calendarId: widget.calendarId,
          title: title,
          start: start,
          end: _allDayUtc(DateTime(_day.year, _day.month, _day.day + 1)),
          timezone: timezone,
          isAllDay: true,
          recurrence: const RecurrenceRule(frequency: Frequency.yearly),
        );
      case ContactEventKind.dayOff:
        final last = _lastDay.isBefore(_day) ? _day : _lastDay;
        return EventDraft(
          calendarId: widget.calendarId,
          title: title,
          start: _allDayUtc(_day),
          end: _allDayUtc(DateTime(last.year, last.month, last.day + 1)),
          timezone: timezone,
          isAllDay: true,
        );
      case ContactEventKind.workHours:
        final day = _isEditing ? _day : _firstWorkDay(_day);
        final start = DateTime(
          day.year,
          day.month,
          day.day,
          _workStart.hour,
          _workStart.minute,
        );
        var end = DateTime(
          day.year,
          day.month,
          day.day,
          _workEnd.hour,
          _workEnd.minute,
        );
        // Fin avant le début : un horaire de nuit, qui finit le lendemain.
        if (!end.isAfter(start)) {
          end = DateTime(
            day.year,
            day.month,
            day.day + 1,
            _workEnd.hour,
            _workEnd.minute,
          );
        }
        return EventDraft(
          calendarId: widget.calendarId,
          title: title,
          location: _location.text,
          start: start.toUtc(),
          end: end.toUtc(),
          timezone: timezone,
          recurrence: RecurrenceRule(
            frequency: Frequency.weekly,
            weekdays: _workDays,
            until: _until,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: CalendarKeys.contactForm,
      appBar: AppBar(
        title: Text(switch (widget.kind) {
          ContactEventKind.birthday => l10n.shortcutBirthday,
          ContactEventKind.workHours => l10n.shortcutWorkHours,
          ContactEventKind.dayOff => l10n.shortcutDayOff,
        }),
        actions: [
          if (_isEditing)
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: CalendarKeys.title,
                controller: _title,
                decoration: InputDecoration(labelText: l10n.eventTitleLabel),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  return trimmed.isEmpty || trimmed.length > _maxTitleLength
                      ? l10n.validationTitle
                      : null;
                },
              ),
              const SizedBox(height: 8),
              ...switch (widget.kind) {
                ContactEventKind.birthday => _birthdayFields(l10n),
                ContactEventKind.dayOff => _dayOffFields(l10n),
                ContactEventKind.workHours => _workFields(l10n),
              },
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

  String _formatDay(DateTime day) =>
      DateFormat.yMMMEd(Localizations.localeOf(context).toString()).format(day);

  String _formatTime(TimeOfDay time) =>
      DateFormat.Hm(Localizations.localeOf(context).toString())
          .format(DateTime(2024, 1, 1, time.hour, time.minute));

  Widget _dateTile(
    Key key,
    IconData icon,
    String label,
    DateTime day, {
    required VoidCallback onTap,
  }) => ListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(_formatDay(day)),
    onTap: onTap,
  );

  List<Widget> _birthdayFields(AppLocalizations l10n) => [
    _dateTile(
      CalendarKeys.contactFormDate,
      Icons.cake_outlined,
      l10n.contactFormDateLabel,
      _day,
      onTap: _pickDay,
    ),
  ];

  List<Widget> _dayOffFields(AppLocalizations l10n) => [
    _dateTile(
      CalendarKeys.contactFormDate,
      Icons.event_outlined,
      l10n.dayOffFromLabel,
      _day,
      onTap: _pickDay,
    ),
    _dateTile(
      CalendarKeys.contactFormDateTo,
      Icons.event_available_outlined,
      l10n.dayOffToLabel,
      _lastDay.isBefore(_day) ? _day : _lastDay,
      onTap: _pickLastDay,
    ),
  ];

  List<Widget> _workFields(AppLocalizations l10n) {
    final endsNextDay =
        _workEnd.hour * 60 + _workEnd.minute <
        _workStart.hour * 60 + _workStart.minute;
    final until = _until;
    return [
      Text(l10n.workDaysLabel, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 4),
      WeekdayChips(selected: _workDays, onToggle: _toggleDay),
      ListTile(
        key: CalendarKeys.workFrom,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule),
        title: Text(l10n.workFromLabel),
        subtitle: Text(_formatTime(_workStart)),
        onTap: () => _pickTime(isStart: true),
      ),
      ListTile(
        key: CalendarKeys.workTo,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule_outlined),
        title: Text(l10n.workToLabel),
        subtitle: Text(
          endsNextDay
              ? l10n.workEndsNextDay(_formatTime(_workEnd))
              : _formatTime(_workEnd),
        ),
        onTap: () => _pickTime(isStart: false),
      ),
      if (_workError case final error?) FormErrorText(error),
      TextFormField(
        key: CalendarKeys.location,
        controller: _location,
        decoration: InputDecoration(
          labelText: l10n.eventLocationLabel,
          prefixIcon: const Icon(Icons.place_outlined),
        ),
      ),
      const SizedBox(height: 8),
      // En modification, le jour est celui de l'occurrence ouverte.
      if (!_isEditing)
        _dateTile(
          CalendarKeys.workStartsOn,
          Icons.event_outlined,
          l10n.workStartsOnLabel,
          _day,
          onTap: _pickDay,
        ),
      ListTile(
        key: CalendarKeys.workUntil,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_busy_outlined),
        title: Text(l10n.workUntilLabel),
        subtitle: Text(
          until == null ? l10n.workUntilNone : _formatDay(until.toLocal()),
        ),
        trailing: until == null
            ? null
            : IconButton(
                key: CalendarKeys.workUntilClear,
                tooltip: l10n.repeatEndClearTooltip,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _until = null),
              ),
        onTap: _pickUntil,
      ),
    ];
  }
}

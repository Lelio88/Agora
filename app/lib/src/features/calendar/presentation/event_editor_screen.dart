/// Éditeur d'un rdv : création, ou modification d'une instance de l'agenda.
///
/// Il n'écrit rien lui-même : il renvoie un [EditorResult] à l'écran
/// d'agenda, qui pose la question « cette occurrence ou la série » s'il y a
/// lieu, puis appelle le service. L'éditeur reste ainsi testable seul, et la
/// question de portée n'existe qu'à un endroit. Ouvert par une route
/// (proposer un rdv à un groupe), il confie son résultat à
/// [EventEditorScreen.onResult] et ne se ferme que s'il a abouti.
///
/// Sur un rdv ponctuel de mes agendas, il lit seulement combien de rdv lui
/// sont semblables (`similar_events.dart`, les séances d'un cours saisies
/// une à une) : s'il y en a, une case propose de leur recopier ce qui a
/// changé, et dit quoi ; [EditorSaved.applyToSimilar] porte ce choix.
///
/// Pour un agenda de groupe, pas de réglage de visibilité : un rdv du
/// groupe est vu en détail de tous ses membres. Pour l'agenda d'un proche
/// non plus : il est invisible des groupes quoi qu'on règle ici.
///
/// Une création peut arriver préremplie (titre, journée entière, règle) :
/// ce sont les raccourcis de la page d'un proche (anniversaire, horaires de
/// travail, repos), qui restent ainsi un rdv ordinaire, modifiable avant
/// d'être enregistré. Un rdv préparé dans une autre app (lien `#/event`)
/// arrive de même avec son lieu, sa description et un bandeau ([notice]),
/// et peut aller dans un agenda de groupe : il est alors proposé au groupe.
///
/// Une répétition hebdomadaire choisit ses jours ; sans choix, elle suit le
/// jour du rdv (pas de BYDAY), ce qui laisse les jours suivre un rdv déplacé.
///
/// Dates et heures sont saisies dans le fuseau local de l'appareil et
/// stockées en UTC ; un rdv « journée entière » va de minuit UTC à minuit
/// UTC (fin exclue), sur sa date locale. L'éditeur en montre le dernier jour
/// inclus, relu par [AgendaItem.localEnd] et jamais par `toLocal()`.
library;

import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/domain/similar_events.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/visibility_field.dart';
import 'package:agora/src/features/calendar/presentation/weekday_chips.dart';
import 'package:agora/src/features/directions/presentation/go_there_button.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const _maxTitleLength = 200;
const _defaultDuration = Duration(hours: 1);

sealed class EditorResult {
  const EditorResult();
}

final class EditorSaved extends EditorResult {
  const EditorSaved(this.draft, {this.applyToSimilar = false});
  final EventDraft draft;

  /// Recopier aussi ce qui a changé sur les rdv semblables (rdv ponctuel).
  final bool applyToSimilar;
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
    this.initialEnd,
    this.initialTitle,
    this.initialAllDay = false,
    this.initialRecurrence,
    this.initialLocation,
    this.initialDescription,
    this.notice,
    this.onResult,
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

  /// Fin proposée à la création (créneau trouvé libre) : début et fin sont
  /// alors repris tels quels, sans arrondi.
  final DateTime? initialEnd;

  /// Titre proposé à la création (raccourci).
  final String? initialTitle;

  /// Création en journée entière (raccourci).
  final bool initialAllDay;

  /// Répétition proposée à la création (raccourci).
  final RecurrenceRule? initialRecurrence;

  /// Lieu et description proposés à la création (rdv venu d'une autre app).
  final String? initialLocation;
  final String? initialDescription;

  /// Affiché en tête du formulaire : d'où vient un rdv prérempli.
  final Widget? notice;

  /// Traite le résultat sans fermer l'éditeur ; vrai s'il a abouti, et
  /// l'éditeur se ferme alors en rendant `true`. Sans lui, l'éditeur se
  /// ferme en rendant le [EditorResult].
  final Future<bool> Function(EditorResult result)? onResult;

  /// Ouvre l'éditeur et renvoie ce que l'utilisateur a décidé, ou `null`.
  static Future<EditorResult?> show(
    BuildContext context, {
    required String calendarId,
    required String timezone,
    List<UserCalendar> calendars = const [],
    AgendaItem? existing,
    DateTime? initialStart,
    DateTime? initialEnd,
    String? initialTitle,
    bool initialAllDay = false,
    RecurrenceRule? initialRecurrence,
  }) => Navigator.of(context).push<EditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EventEditorScreen(
        calendarId: calendarId,
        timezone: timezone,
        calendars: calendars,
        existing: existing,
        initialStart: initialStart,
        initialEnd: initialEnd,
        initialTitle: initialTitle,
        initialAllDay: initialAllDay,
        initialRecurrence: initialRecurrence,
      ),
    ),
  );

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.existing?.title ?? widget.initialTitle,
  );
  late final _location = TextEditingController(
    text: widget.existing?.location ?? widget.initialLocation,
  );
  late final _description = TextEditingController(
    text: widget.existing?.description ?? widget.initialDescription,
  );
  late DateTime _start;
  late DateTime _end;
  late bool _isAllDay = widget.existing?.isAllDay ?? widget.initialAllDay;
  late EventVisibility? _visibility = widget.existing?.visibility;
  late String _calendarId = widget.existing?.calendarId ?? widget.calendarId;
  bool _isSending = false;
  bool _applyToSimilar = false;

  /// Le rdv va dans l'agenda d'un groupe : tous ses membres le voient.
  bool get _inGroupCalendar => widget.calendars.any(
    (calendar) => calendar.id == _calendarId && !calendar.isPersonal,
  );

  /// Le rdv va dans l'agenda d'un proche : aucun groupe ne le voit.
  bool get _inContactCalendar => widget.calendars.any(
    (calendar) => calendar.id == _calendarId && calendar.isContact,
  );

  /// Règle éditable ; `null` sans répétition. Une règle importée hors du
  /// sous-ensemble éditable est gardée telle quelle dans [_advancedRule].
  late RecurrenceRule? _recurrence;
  late final String? _advancedRule;
  String? _rangeError;

  /// Le rdv ouvert est ponctuel, dans un de mes agendas, et le reste : ses
  /// semblables peuvent recevoir la même modification. Devenu une série, il
  /// n'en a plus (la case disparaît, et avec elle le choix).
  bool get _offersSimilar {
    final existing = widget.existing;
    return existing != null &&
        canHaveSimilar(existing) &&
        widget.calendars.any(
          (calendar) =>
              calendar.id == existing.calendarId && calendar.isWritable,
        ) &&
        _recurrence == null &&
        _advancedRule == null;
  }

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
    } else if ((widget.initialStart, widget.initialEnd) case (
      final start?,
      final end?,
    )) {
      _start = start.toLocal();
      _end = end.toLocal();
      _recurrence = widget.initialRecurrence;
      _advancedRule = null;
    } else {
      _start = _roundedStart(widget.initialStart?.toLocal() ?? DateTime.now());
      _end = _start.add(_defaultDuration);
      _recurrence = widget.initialRecurrence;
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

    _finish(
      EditorSaved(_draft(), applyToSimilar: _offersSimilar && _applyToSimilar),
    );
  }

  /// Le rdv tel que le formulaire le décrit en ce moment.
  EventDraft _draft() {
    final (start, end) = _isAllDay
        ? (
            _allDayUtc(_start),
            _allDayUtc(_end.isBefore(_start) ? _start : _end)
                .add(const Duration(days: 1)),
          )
        : (_start.toUtc(), _end.toUtc());
    return EventDraft(
      calendarId: _calendarId,
      title: _title.text,
      location: _location.text,
      description: _description.text,
      start: start,
      end: end,
      isAllDay: _isAllDay,
      timezone: widget.existing?.timezone ?? widget.timezone,
      recurrence: _recurrence,
      visibility: _inGroupCalendar || _inContactCalendar ? null : _visibility,
    ).withRawRule(_advancedRule);
  }

  Future<void> _finish(EditorResult result) async {
    final onResult = widget.onResult;
    if (onResult == null) {
      Navigator.of(context).pop(result);
      return;
    }
    setState(() => _isSending = true);
    final done = await onResult(result);
    if (!mounted) return;
    setState(() => _isSending = false);
    if (done) Navigator.of(context).pop(true);
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
              onPressed: () => _finish(const EditorDeleteRequested()),
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
              if (widget.notice case final notice?) ...[
                notice,
                const SizedBox(height: 8),
              ],
              TextFormField(
                key: CalendarKeys.title,
                controller: _title,
                autofocus: !isEditing && widget.initialTitle == null,
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
                  // Le choix mêle mon agenda et ceux de mes groupes : dire
                  // ce qu'un agenda de groupe change.
                  helper: _inGroupCalendar ? l10n.eventProposedToGroup : null,
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
              if (_advancedRule == null)
                if (_recurrence case final rule?)
                  _RepeatDetails(
                    rule: rule,
                    startDay: _start,
                    onChanged: (rule) => setState(() => _recurrence = rule),
                  ),
              if (!_inGroupCalendar && !_inContactCalendar)
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
              // Sur un rdv déjà enregistré seulement : à la création, on
              // saisit le rdv, on ne s'y rend pas encore.
              if (widget.existing != null)
                ValueListenableBuilder(
                  valueListenable: _location,
                  builder: (context, value, _) => GoThereButton(
                    location: value.text,
                    start: _start,
                    isAllDay: _isAllDay,
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
              if (_offersSimilar)
                if (widget.existing case final existing?)
                  // Relu à chaque frappe : la case dit ce qu'elle recopiera.
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _title,
                      _location,
                      _description,
                    ]),
                    builder: (context, _) => _SimilarEventsField(
                      item: existing,
                      changes: similarChanges(existing, _draft()),
                      value: _applyToSimilar,
                      onChanged: (value) =>
                          setState(() => _applyToSimilar = value),
                    ),
                  ),
              const SizedBox(height: 24),
              SubmitButton(
                key: CalendarKeys.save,
                label: l10n.saveButton,
                isLoading: _isSending,
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
      // Changer de fréquence repart de ses réglages par défaut, mais garde
      // la date de fin déjà choisie.
      onSelected: (frequency) => onChanged(
        frequency == null
            ? null
            : RecurrenceRule(frequency: frequency, until: recurrence?.until),
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

/// Réglages d'une répétition simple : pour une répétition hebdomadaire, ses
/// jours et son rythme (une semaine sur combien) ; pour toutes, sa fin.
///
/// Sans jour choisi, la règle n'a pas de BYDAY : elle suit le jour du rdv,
/// que les puces montrent coché. On ne peut pas décocher le dernier jour.
class _RepeatDetails extends StatelessWidget {
  const _RepeatDetails({
    required this.rule,
    required this.startDay,
    required this.onChanged,
  });

  final RecurrenceRule rule;

  /// Début du rdv : son jour tient lieu de jours choisis, et la fin ne
  /// peut pas le précéder.
  final DateTime startDay;
  final ValueChanged<RecurrenceRule> onChanged;

  static const _maxWeeks = 4;

  Set<int> get _days =>
      rule.weekdays.isEmpty ? {startDay.weekday} : rule.weekdays;

  void _toggle(int weekday) {
    final days = {..._days};
    if (!days.remove(weekday)) days.add(weekday);
    if (days.isEmpty) return;
    onChanged(rule.copyWith(weekdays: days));
  }

  Future<void> _pickEnd(BuildContext context) async {
    final first = DateTime(startDay.year, startDay.month, startDay.day);
    final current = rule.until?.toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null || current.isBefore(first) ? first : current,
      firstDate: first,
      lastDate: DateTime(first.year + 10, first.month, first.day),
    );
    if (picked == null) return;
    // Fin incluse : jusqu'au dernier instant de ce jour, à l'heure locale.
    final until = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    onChanged(rule.copyWith(until: () => until.toUtc(), count: () => null));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final until = rule.until;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rule.frequency == Frequency.weekly) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 40, bottom: 4),
            child: Text(
              l10n.repeatDaysLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 40),
            child: WeekdayChips(selected: _days, onToggle: _toggle),
          ),
          PopupMenuButton<int>(
            key: CalendarKeys.repeatInterval,
            onSelected: (weeks) => onChanged(rule.copyWith(interval: weeks)),
            itemBuilder: (context) => [
              for (var weeks = 1; weeks <= _maxWeeks; weeks++)
                PopupMenuItem(
                  key: CalendarKeys.repeatIntervalOption(weeks),
                  value: weeks,
                  child: Text(l10n.repeatEveryWeeks(weeks)),
                ),
            ],
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const SizedBox(width: 24),
              title: Text(l10n.repeatIntervalLabel),
              subtitle: Text(l10n.repeatEveryWeeks(rule.interval)),
              trailing: const Icon(Icons.arrow_drop_down),
            ),
          ),
        ],
        ListTile(
          key: CalendarKeys.repeatEnd,
          contentPadding: EdgeInsets.zero,
          leading: const SizedBox(width: 24),
          title: Text(l10n.repeatEndLabel),
          subtitle: Text(
            until == null
                ? l10n.repeatEndNever
                : l10n.repeatEndOn(
                    DateFormat.yMMMEd(locale).format(until.toLocal()),
                  ),
          ),
          trailing: until == null
              ? null
              : IconButton(
                  key: CalendarKeys.repeatEndClear,
                  tooltip: l10n.repeatEndClearTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(rule.copyWith(until: () => null)),
                ),
          onTap: () => _pickEnd(context),
        ),
      ],
    );
  }
}

/// Case « appliquer aussi aux semblables » d'un rdv ponctuel : absente tant
/// que le serveur n'en compte aucun (ou si la lecture échoue, que
/// `AsyncErrorLogger` journalise) ; dit leur nombre, leur créneau et ce qui
/// sera recopié.
class _SimilarEventsField extends ConsumerWidget {
  const _SimilarEventsField({
    required this.item,
    required this.changes,
    required this.value,
    required this.onChanged,
  });

  /// Le rdv ouvert, tel qu'il est enregistré.
  final AgendaItem item;
  final Set<SimilarField> changes;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(similarEventsCountProvider(item.eventId)).value ?? 0;
    if (count == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final start = item.localStart;
    final weekday = DateFormat.EEEE(locale).format(start);
    final slot = item.isAllDay
        ? l10n.similarEventsSlotAllDay(weekday)
        : l10n.similarEventsSlot(weekday, DateFormat.Hm(locale).format(start));
    String label(SimilarField field) => switch (field) {
      SimilarField.title => l10n.similarFieldTitle,
      SimilarField.location => l10n.similarFieldLocation,
      SimilarField.description => l10n.similarFieldDescription,
      SimilarField.visibility => l10n.similarFieldVisibility,
      SimilarField.calendar => l10n.similarFieldCalendar,
    };
    return CheckboxListTile(
      key: CalendarKeys.applyToSimilar,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: (checked) => onChanged(checked ?? false),
      title: Text(l10n.similarEventsApply(count, item.title)),
      subtitle: Text(
        changes.isEmpty
            ? l10n.similarEventsCopiesNothing(slot)
            : l10n.similarEventsCopies(slot, changes.map(label).join(', ')),
      ),
    );
  }
}

class _CalendarField extends StatelessWidget {
  const _CalendarField({
    required this.calendars,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final List<UserCalendar> calendars;
  final String value;
  final String? helper;
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
        helperText: helper,
        helperMaxLines: 2,
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

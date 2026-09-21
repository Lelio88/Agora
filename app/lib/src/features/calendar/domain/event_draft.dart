/// Ce que l'utilisateur saisit pour créer ou modifier un rdv.
///
/// [start] et [end] sont des instants UTC ; [timezone] est le fuseau dans
/// lequel la série se répète (un rdv à 18 h reste à 18 h après le changement
/// d'heure). Un rdv « journée entière » va de minuit UTC à minuit UTC.
///
/// [rawRule] porte une RRULE importée que l'éditeur ne sait pas représenter
/// (voir `RecurrenceRule.parse`) : elle est renvoyée telle quelle au
/// serveur, jamais réécrite. [rrule] est la règle effective.
library;

import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';

final class EventDraft {
  const EventDraft({
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    required this.timezone,
    this.isAllDay = false,
    this.location,
    this.description,
    this.recurrence,
    this.visibility,
    this.rawRule,
  }) : assert(
         recurrence == null || rawRule == null,
         'a raw rule replaces the editable recurrence',
       );

  final String calendarId;
  final String title;
  final DateTime start;
  final DateTime end;
  final String timezone;
  final bool isAllDay;
  final String? location;
  final String? description;
  final RecurrenceRule? recurrence;
  final EventVisibility? visibility;
  final String? rawRule;

  /// Règle envoyée au serveur, ou `null` pour un rdv ponctuel.
  String? get rrule => rawRule ?? recurrence?.toRRule();

  /// Garde une règle importée telle quelle (aucun effet si `null`).
  EventDraft withRawRule(String? raw) => raw == null
      ? this
      : EventDraft(
          calendarId: calendarId,
          title: title,
          start: start,
          end: end,
          timezone: timezone,
          isAllDay: isAllDay,
          location: location,
          description: description,
          visibility: visibility,
          rawRule: raw,
        );

  EventDraft copyWith({
    String? calendarId,
    String? title,
    DateTime? start,
    DateTime? end,
    String? timezone,
    bool? isAllDay,
    String? Function()? location,
    String? Function()? description,
    RecurrenceRule? Function()? recurrence,
    EventVisibility? Function()? visibility,
  }) => EventDraft(
    calendarId: calendarId ?? this.calendarId,
    title: title ?? this.title,
    start: start ?? this.start,
    end: end ?? this.end,
    timezone: timezone ?? this.timezone,
    isAllDay: isAllDay ?? this.isAllDay,
    location: location == null ? this.location : location(),
    description: description == null ? this.description : description(),
    recurrence: recurrence == null ? this.recurrence : recurrence(),
    visibility: visibility == null ? this.visibility : visibility(),
    rawRule: recurrence == null ? rawRule : null,
  );
}

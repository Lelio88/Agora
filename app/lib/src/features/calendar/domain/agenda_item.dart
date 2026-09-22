/// Une instance affichable de l'agenda, telle que la renvoie `my_agenda()` :
/// un rdv ponctuel, une occurrence dépliée d'une série, ou une occurrence
/// modifiée (rdv à part, rattaché à sa série par [seriesId] et le créneau
/// d'origine [originalStart]).
///
/// Invariant : [instanceKey] identifie l'instance à l'écran, pas seulement
/// le rdv. Deux occurrences d'une même série partagent [eventId] mais pas
/// leur créneau.
library;

import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';

enum InstanceKind { single, seriesOccurrence, modifiedOccurrence }

final class AgendaItem {
  const AgendaItem({
    required this.eventId,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    required this.isAllDay,
    required this.timezone,
    this.seriesId,
    this.originalStart,
    this.location,
    this.description,
    this.rrule,
    this.visibility,
    this.myResponse,
  });

  final String eventId;
  final String calendarId;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
  final String timezone;

  /// Série d'appartenance ; pour une occurrence dépliée, égal à [eventId].
  final String? seriesId;

  /// Créneau d'origine dans la série (avant décalage éventuel).
  final DateTime? originalStart;
  final String? location;
  final String? description;
  final String? rrule;
  final EventVisibility? visibility;

  /// Ma réponse à un rdv de groupe ; `null` sans réponse, ou hors groupe.
  final ResponseStatus? myResponse;

  InstanceKind get kind {
    if (seriesId == null) return InstanceKind.single;
    return seriesId == eventId
        ? InstanceKind.seriesOccurrence
        : InstanceKind.modifiedOccurrence;
  }

  bool get isRecurring => seriesId != null;

  /// L'instance à laquelle on répond, pour un rdv de groupe : une occurrence
  /// dépliée d'une série se répond par son créneau ; tout le reste (rdv
  /// ponctuel, occurrence modifiée, qui est une ligne à part) sans créneau.
  ResponseKey get responseKey => kind == InstanceKind.seriesOccurrence
      ? ResponseKey(eventId, originalStart)
      : ResponseKey(eventId);

  /// Début à afficher, dans le fuseau de l'appareil. Un rdv journée entière
  /// est une date de calendrier, stockée de minuit UTC à minuit UTC : elle
  /// se lit sur ses composants UTC, jamais par `toLocal()`, qui la reculerait
  /// d'un jour dans un fuseau négatif (Amériques).
  DateTime get localStart => isAllDay ? _calendarDate(start) : start.toLocal();

  /// Fin à afficher ; pour une journée entière, minuit (exclu) du lendemain
  /// du dernier jour.
  DateTime get localEnd => isAllDay ? _calendarDate(end) : end.toLocal();

  static DateTime _calendarDate(DateTime instant) {
    final utc = instant.toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// Clé unique de l'instance affichée.
  String get instanceKey => originalStart == null
      ? eventId
      : '$eventId@${originalStart!.toIso8601String()}';

  @override
  bool operator ==(Object other) =>
      other is AgendaItem &&
      other.instanceKey == instanceKey &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.myResponse == myResponse;

  @override
  int get hashCode => Object.hash(instanceKey, title, start, end, myResponse);
}

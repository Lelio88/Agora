/// Lecture d'un rdv de groupe pour sa fiche : l'instance voulue et les
/// réponses des membres.
///
/// Choix non évident : la fiche se relit au rythme du temps réel de
/// l'agenda (un rdv modifié ou supprimé ailleurs y apparaît aussitôt) ; les
/// réponses, elles, ne sont pas publiées en temps réel et se relisent après
/// chaque action (voir `CalendarService`).
library;

import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/domain/calendar_repository.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Le rdv [eventId] ; [start] désigne l'occurrence d'une série.
final class GroupEventQuery {
  GroupEventQuery(this.eventId, {DateTime? start}) : start = start?.toUtc();

  final String eventId;
  final DateTime? start;

  @override
  bool operator ==(Object other) =>
      other is GroupEventQuery &&
      other.eventId == eventId &&
      other.start == start;

  @override
  int get hashCode => Object.hash(eventId, start);
}

/// L'instance d'un rdv de groupe, ou `null` si elle n'existe plus.
final groupEventProvider = FutureProvider.autoDispose
    .family<GroupEventInstance?, GroupEventQuery>((ref, query) {
      ref.watch(agendaChangesProvider);
      return ref
          .watch(calendarRepositoryProvider)
          .fetchInstance(query.eventId, start: query.start);
    });

/// Les réponses des membres à une instance.
final eventResponsesProvider = FutureProvider.autoDispose
    .family<List<EventResponse>, ResponseKey>(
      (ref, key) => ref.watch(calendarRepositoryProvider).fetchResponses(key),
    );

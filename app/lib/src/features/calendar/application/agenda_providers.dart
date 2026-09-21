/// Lecture de l'agenda : un provider par plage de dates, rafraîchi par le
/// flux de changements (temps réel) du dépôt.
///
/// Choix non évident : [agendaProvider] est une famille sur [AgendaRange],
/// pas un provider unique. Les vues (semaine, mois, planning) demandent des
/// plages différentes, et une plage déjà chargée reste en cache tant qu'un
/// widget la regarde. Le flux [agendaChangesProvider] les invalide toutes.
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/calendar_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => throw UnimplementedError(
    'calendarRepositoryProvider must be overridden at the composition root.',
  ),
);

/// Plage [from, to[ en UTC, alignée sur des jours entiers.
final class AgendaRange {
  const AgendaRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is AgendaRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Compteur de changements côté serveur ; chaque tick recharge l'agenda.
final agendaChangesProvider = StreamProvider<int>(
  (ref) => ref.watch(calendarRepositoryProvider).watchChanges(),
);

final agendaProvider = FutureProvider.autoDispose
    .family<List<AgendaItem>, AgendaRange>((ref, range) {
      ref.watch(agendaChangesProvider);
      return ref
          .watch(calendarRepositoryProvider)
          .fetchAgenda(range.from, range.to);
    });

/// Identifiant de l'agenda natif par défaut, où les rdv se créent.
final defaultCalendarIdProvider = FutureProvider<String>(
  (ref) => ref.watch(calendarRepositoryProvider).defaultCalendarId(),
);

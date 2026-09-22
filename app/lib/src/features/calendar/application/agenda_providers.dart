/// Lecture de l'agenda : un provider par plage de dates, rafraîchi par le
/// flux de changements (temps réel) du dépôt.
///
/// Choix non évident : [agendaProvider] est une famille sur [AgendaRange],
/// pas un provider unique. Les vues (semaine, mois, planning) demandent des
/// plages différentes, et une plage déjà chargée reste en cache tant qu'un
/// widget la regarde. Le flux [agendaChangesProvider] les invalide toutes.
///
/// [visibleAgendaProvider] retire les agendas que l'utilisateur a masqués
/// dans sa vue : un simple filtre local, relu à chaque changement de la
/// liste des agendas, sans recharger les rdv.
library;

import 'package:agora/src/features/calendar/application/calendars_providers.dart';
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

/// L'agenda de la plage, sans les agendas masqués par l'utilisateur.
final visibleAgendaProvider = FutureProvider.autoDispose
    .family<List<AgendaItem>, AgendaRange>((ref, range) async {
      final items = await ref.watch(agendaProvider(range).future);
      final calendars = await ref.watch(calendarsProvider.future);
      final hidden = {
        for (final calendar in calendars)
          if (calendar.hidden) calendar.id,
      };
      return items
          .where((item) => !hidden.contains(item.calendarId))
          .toList(growable: false);
    });

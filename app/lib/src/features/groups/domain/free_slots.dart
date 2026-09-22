/// Créneaux communs : les plages où aucun des membres choisis n'est pris,
/// dans une fenêtre quotidienne, à partir de l'agenda du groupe.
///
/// Choix non évidents :
/// - le calcul part de `group_agenda`, déjà passé par la règle de vie
///   privée : « occupé » et détail comptent comme pris, un membre qui ne
///   partage rien (« invisible ») n'a aucun créneau et paraît donc libre —
///   l'écran le signale ;
/// - un rdv du groupe lui-même prend le créneau pour tout le monde : on
///   ne cherche pas à caler un rdv par-dessus un autre du groupe ;
/// - une journée entière ne prend rien par défaut (anniversaire, jour
///   férié) ; [SlotSearch.allDayBlocks] la compte sur toute la journée ;
/// - tout se calcule en heure locale de l'appareil, jour par jour, par le
///   constructeur de `DateTime` : « 18 h » reste 18 h un jour de
///   changement d'heure ;
/// - un créneau ne commence jamais dans le passé : au plus tôt au quart
///   d'heure qui suit [SlotSearch.from].
///
/// Invariant : fonction pure (aucune E/S), testée seule.
library;

import 'package:agora/src/features/groups/domain/group_agenda_item.dart';

/// Nombre maximal de créneaux rendus.
const maxFreeSlots = 50;

const _quarter = Duration(minutes: 15);

/// Ce que l'on cherche.
final class SlotSearch {
  const SlotSearch({
    required this.from,
    required this.to,
    required this.duration,
    required this.dayStart,
    required this.dayEnd,
    required this.weekdays,
    required this.members,
    this.allDayBlocks = false,
  });

  /// Période [from, to[, en heure locale.
  final DateTime from;
  final DateTime to;

  /// Durée minimale d'un créneau.
  final Duration duration;

  /// Fenêtre quotidienne, depuis minuit : [dayStart, dayEnd[. Une fenêtre
  /// qui passerait minuit n'est pas prise en charge (elle est vide).
  final Duration dayStart;
  final Duration dayEnd;

  /// Jours retenus (`DateTime.monday` = 1 … `DateTime.sunday` = 7).
  final Set<int> weekdays;

  /// Membres dont on veut la présence (identifiants).
  final Set<String> members;

  /// Une journée entière prend-elle la journée ?
  final bool allDayBlocks;
}

/// Une plage libre pour tous, en heure locale.
final class FreeSlot {
  const FreeSlot(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration get length => end.difference(start);
}

/// Les plages libres de [search] dans [agenda], par ordre chronologique, au
/// plus [maxFreeSlots].
List<FreeSlot> findFreeSlots(SlotSearch search, List<GroupAgendaItem> agenda) {
  if (search.dayEnd <= search.dayStart) return const [];
  final busy = _busyIntervals(search, agenda);
  final earliest = _nextQuarter(search.from);
  final slots = <FreeSlot>[];
  for (
    var day = DateTime(search.from.year, search.from.month, search.from.day);
    day.isBefore(search.to) && slots.length < maxFreeSlots;
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (!search.weekdays.contains(day.weekday)) continue;
    var start = _at(day, search.dayStart);
    var end = _at(day, search.dayEnd);
    if (start.isBefore(earliest)) start = earliest;
    if (end.isAfter(search.to)) end = search.to;
    for (final free in _subtract(start, end, busy)) {
      if (free.length >= search.duration) slots.add(free);
      if (slots.length == maxFreeSlots) break;
    }
  }
  return slots;
}

/// Heure [offset] du jour [day], en heure locale (sans passer par une
/// addition de durée, fausse un jour de changement d'heure).
DateTime _at(DateTime day, Duration offset) => DateTime(
  day.year,
  day.month,
  day.day,
  offset.inHours,
  offset.inMinutes.remainder(60),
);

DateTime _nextQuarter(DateTime instant) {
  final local = instant.toLocal();
  final floor = DateTime(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute - local.minute % 15,
  );
  return floor.isBefore(local) ? floor.add(_quarter) : floor;
}

/// Les intervalles pris, triés et fusionnés, en heure locale.
List<FreeSlot> _busyIntervals(SlotSearch search, List<GroupAgendaItem> agenda) {
  final intervals = <FreeSlot>[
    for (final item in agenda)
      if (item.isGroupEvent || search.members.contains(item.userId))
        if (!item.isAllDay || search.allDayBlocks)
          FreeSlot(item.localStart, item.localEnd),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <FreeSlot>[];
  for (final interval in intervals) {
    final last = merged.lastOrNull;
    if (last != null && !interval.start.isAfter(last.end)) {
      if (interval.end.isAfter(last.end)) {
        merged[merged.length - 1] = FreeSlot(last.start, interval.end);
      }
    } else {
      merged.add(interval);
    }
  }
  return merged;
}

/// [start, end[ privé des intervalles [busy] (triés, fusionnés).
List<FreeSlot> _subtract(DateTime start, DateTime end, List<FreeSlot> busy) {
  final free = <FreeSlot>[];
  var cursor = start;
  for (final interval in busy) {
    if (!interval.end.isAfter(cursor)) continue;
    if (!interval.start.isBefore(end)) break;
    if (interval.start.isAfter(cursor)) {
      free.add(FreeSlot(cursor, interval.start));
    }
    cursor = interval.end;
    if (!cursor.isBefore(end)) return free;
  }
  if (cursor.isBefore(end)) free.add(FreeSlot(cursor, end));
  return free;
}

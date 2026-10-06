/// Ce qu'un membre partage dans les groupes qu'on a en commun avec lui :
/// ses créneaux de chacun de ces groupes, réunis (page d'un proche relié à
/// ce membre).
///
/// Choix non évidents :
/// - chaque groupe rend déjà les créneaux passés par la règle de vie
///   privée (`group_agenda()`) ; les réunir n'en montre pas plus que ce
///   qu'on voit en ouvrant chacun de ces groupes, et la règle reste en base ;
/// - un même créneau vu dans deux groupes n'apparaît qu'une fois, au niveau
///   le plus détaillé : un rdv en détail l'emporte sur un « occupé » aux
///   mêmes heures.
///
/// Invariant : fonction pure ; les rdv des groupes eux-mêmes (sans membre)
/// n'y entrent pas.
library;

import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';

/// Les créneaux de [userId] parmi [agendas] (un par groupe commun), une
/// fois chacun, du plus tôt au plus tard.
List<GroupAgendaItem> memberSharedAgenda(
  String userId,
  Iterable<List<GroupAgendaItem>> agendas,
) {
  final mine = [
    for (final agenda in agendas)
      for (final slot in agenda)
        if (slot.userId == userId) slot,
  ];
  final detailed = <(String?, DateTime), GroupAgendaItem>{
    for (final slot in mine)
      if (slot.level == ShareLevel.details) (slot.eventId, slot.start): slot,
  };
  bool hiddenByDetail(GroupAgendaItem busy) => detailed.values.any(
    (slot) => slot.start == busy.start && slot.end == busy.end,
  );
  final busy = <(DateTime, DateTime, bool), GroupAgendaItem>{
    for (final slot in mine)
      if (slot.level != ShareLevel.details && !hiddenByDetail(slot))
        (slot.start, slot.end, slot.isAllDay): slot,
  };
  return [...detailed.values, ...busy.values]
    ..sort((a, b) => a.start.compareTo(b.start));
}

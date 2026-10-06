/// Lecture de l'agenda d'un proche : ses prochaines dates à retenir
/// (anniversaires) et ce qui y est noté en ce moment.
///
/// Choix non évidents :
/// - une « date à retenir » est un rdv journée entière répété chaque année,
///   dans l'agenda d'un proche : c'est ce que crée le raccourci
///   « Anniversaire », sans marquage de plus en base ;
/// - les jours se comptent en dates de calendrier (`localStart` d'une
///   journée entière, jamais 24 h) : la nuit d'un changement d'heure n'en
///   fait pas 24 ;
/// - [contactMoment] ne dit pas si le proche est « libre » : un « Repos »
///   noté le rend justement disponible. Il dit ce qui est noté, à l'écran de
///   l'interpréter.
///
/// Invariant : fonctions pures, sans horloge ; l'appelant passe `today` ou
/// `now`.
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';

/// Une date à retenir d'un proche, à [daysAway] jours d'aujourd'hui.
final class Anniversary {
  const Anniversary({required this.item, required this.daysAway});

  final AgendaItem item;
  final int daysAway;
}

/// Ce qui est noté dans l'agenda d'un proche à un instant donné.
final class ContactMoment {
  const ContactMoment({required this.current, required this.next});

  /// Les rdv en cours (une journée entière compte pour toute la journée).
  final List<AgendaItem> current;

  /// Le premier rdv qui commence après l'instant, s'il y en a un.
  final AgendaItem? next;
}

/// Un rdv journée entière répété chaque année.
bool isAnniversary(AgendaItem item) {
  final rrule = item.rrule;
  if (!item.isAllDay || rrule == null) return false;
  return RecurrenceRule.parse(rrule)?.frequency == Frequency.yearly;
}

/// Les dates à retenir des agendas [contactCalendarIds] parmi [items], à
/// partir de [today] (inclus), de la plus proche à la plus lointaine.
List<Anniversary> upcomingAnniversaries(
  Iterable<AgendaItem> items, {
  required Set<String> contactCalendarIds,
  required DateTime today,
}) {
  final day = DateTime(today.year, today.month, today.day);
  return [
    for (final item in items)
      if (contactCalendarIds.contains(item.calendarId) && isAnniversary(item))
        Anniversary(item: item, daysAway: _daysBetween(day, item.localStart)),
  ].where((anniversary) => anniversary.daysAway >= 0).toList()..sort((a, b) {
    final byDay = a.daysAway.compareTo(b.daysAway);
    return byDay != 0 ? byDay : a.item.title.compareTo(b.item.title);
  });
}

/// Ce qui est noté à [now] parmi [items], et ce qui vient ensuite.
ContactMoment contactMoment(
  Iterable<AgendaItem> items, {
  required DateTime now,
}) {
  final sorted = items.toList()
    ..sort((a, b) => a.localStart.compareTo(b.localStart));
  return ContactMoment(
    current: [
      for (final item in sorted)
        if (!item.localStart.isAfter(now) && item.localEnd.isAfter(now)) item,
    ],
    next: sorted.where((item) => item.localStart.isAfter(now)).firstOrNull,
  );
}

/// Jours de calendrier de [from] à [to] (dates locales).
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

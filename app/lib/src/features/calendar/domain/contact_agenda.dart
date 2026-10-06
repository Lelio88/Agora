/// Lecture de l'agenda d'un proche : ses prochaines dates à retenir
/// (anniversaires), ce qui y est noté en ce moment, et le formulaire court
/// qui sait montrer chacun de ses rdv.
///
/// Choix non évidents :
/// - trois sortes de rdv se reconnaissent à leur forme, sans marquage de
///   plus en base : une **date à retenir** est une journée entière répétée
///   chaque année, des **horaires de travail** un rdv horaire répété chaque
///   semaine, un **congé** une journée (ou une période) entière qui n'est
///   pas une date à retenir ;
/// - un congé l'emporte sur les horaires de travail des jours qu'il couvre
///   ([withoutWorkOnDaysOff]) ; un jour sans horaires de travail, quand le
///   proche en a d'autres jours, est un **jour de repos**
///   ([ContactMoment.isRestDay]) : les repos se déduisent des jours
///   travaillés, on ne les note pas ;
/// - [contactFormFor] n'ouvre le formulaire court que s'il montre tout ce
///   que le rdv contient : un rdv noté avec plus (des notes, un rythme d'une
///   semaine sur deux, une règle avancée) garde l'éditeur complet, qui ne
///   perd rien ;
/// - les jours se comptent en dates de calendrier (`localStart` d'une
///   journée entière, jamais 24 h) : la nuit d'un changement d'heure n'en
///   fait pas 24 ;
/// - [contactMoment] dit ce qui est noté (et le repos qui s'en déduit),
///   pas si le proche est « libre » : à l'écran de l'interpréter.
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
  const ContactMoment({
    required this.current,
    required this.next,
    this.isRestDay = false,
  });

  /// Les rdv en cours (une journée entière compte pour toute la journée).
  final List<AgendaItem> current;

  /// Le premier rdv qui commence après l'instant, s'il y en a un.
  final AgendaItem? next;

  /// Le proche a des horaires de travail, mais aucun ce jour-là (ni congé).
  final bool isRestDay;
}

/// Les formulaires courts de l'agenda d'un proche.
enum ContactEventKind { birthday, workHours, dayOff }

/// Un rdv journée entière répété chaque année.
bool isAnniversary(AgendaItem item) {
  final rrule = item.rrule;
  if (!item.isAllDay || rrule == null) return false;
  return RecurrenceRule.parse(rrule)?.frequency == Frequency.yearly;
}

/// Des horaires de travail : un rdv horaire répété chaque semaine.
bool isWorkHours(AgendaItem item) {
  final rrule = item.rrule;
  if (item.isAllDay || rrule == null) return false;
  return RecurrenceRule.parse(rrule)?.frequency == Frequency.weekly;
}

/// Un congé : une journée entière qui n'est pas une date à retenir.
bool isDayOff(AgendaItem item) => item.isAllDay && !isAnniversary(item);

/// Le formulaire court qui montre tout [item], ou `null` (éditeur complet).
ContactEventKind? contactFormFor(AgendaItem item) {
  if (_isFilled(item.description)) return null;
  final rrule = item.rrule;
  // Une occurrence d'une série qui ne porte pas sa règle : le formulaire
  // court, qui modifie toute la série, la rendrait ponctuelle.
  if (item.isRecurring && rrule == null) return null;
  final rule = rrule == null ? null : RecurrenceRule.parse(rrule);
  // Règle hors du sous-ensemble éditable : seul l'éditeur complet la garde.
  if (rrule != null && rule == null) return null;
  if (isAnniversary(item)) {
    final plain =
        rule != null &&
        rule.interval == 1 &&
        rule.weekdays.isEmpty &&
        rule.until == null &&
        rule.count == null;
    return plain && !_isFilled(item.location)
        ? ContactEventKind.birthday
        : null;
  }
  if (isWorkHours(item)) {
    return rule != null && rule.interval == 1 && rule.count == null
        ? ContactEventKind.workHours
        : null;
  }
  if (item.isAllDay && rule == null && !_isFilled(item.location)) {
    return ContactEventKind.dayOff;
  }
  return null;
}

/// [items] sans les horaires de travail des jours couverts par un congé,
/// dans le même ordre.
List<AgendaItem> withoutWorkOnDaysOff(Iterable<AgendaItem> items) {
  final daysOff = items.where(isDayOff).toList(growable: false);
  bool coveredByDayOff(AgendaItem work) {
    final day = _date(work.localStart);
    return daysOff.any(
      (off) =>
          !day.isBefore(_date(off.localStart)) &&
          day.isBefore(_date(off.localEnd)),
    );
  }

  return [
    for (final item in items)
      if (!isWorkHours(item) || !coveredByDayOff(item)) item,
  ];
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

/// Ce qui est noté à [now] parmi [items], ce qui vient ensuite, et si le
/// jour de [now] est un jour de repos.
ContactMoment contactMoment(
  Iterable<AgendaItem> items, {
  required DateTime now,
}) {
  final sorted = items.toList()
    ..sort((a, b) => a.localStart.compareTo(b.localStart));
  final today = _date(now);
  // Une journée entière couvre ses jours jusqu'à sa fin exclue ; un rdv
  // horaire compte pour le jour où il commence.
  bool onToday(AgendaItem item) => item.isAllDay
      ? !today.isBefore(_date(item.localStart)) &&
            today.isBefore(_date(item.localEnd))
      : today == _date(item.localStart);
  final work = sorted.where(isWorkHours);
  final current = [
    for (final item in sorted)
      if (!item.localStart.isAfter(now) && item.localEnd.isAfter(now)) item,
  ];
  return ContactMoment(
    current: current,
    next: sorted.where((item) => item.localStart.isAfter(now)).firstOrNull,
    // Un horaire de nuit commencé la veille compte aussi : on travaille.
    isRestDay:
        work.isNotEmpty &&
        !work.any(onToday) &&
        !current.any(isWorkHours) &&
        !sorted.where(isDayOff).any(onToday),
  );
}

bool _isFilled(String? text) => text != null && text.trim().isNotEmpty;

/// Le jour de calendrier de [value], à minuit.
DateTime _date(DateTime value) => DateTime(value.year, value.month, value.day);

/// Jours de calendrier de [from] à [to] (dates locales).
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Créneau d'une instance en toutes lettres, pour les fiches (rdv importé,
/// rdv de groupe).
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:intl/intl.dart';

/// Créneau d'une instance, dans la langue [locale] : une date (ou deux, du
/// premier au dernier jour inclus) pour une journée entière, date et heures
/// sinon.
String eventWhenLabel(AgendaItem item, String locale) => slotWhenLabel(
  localStart: item.localStart,
  localEnd: item.localEnd,
  isAllDay: item.isAllDay,
  locale: locale,
);

/// Même chose pour un créneau quelconque (celui d'un membre dans un
/// groupe), déjà ramené à ses dates locales.
String slotWhenLabel({
  required DateTime localStart,
  required DateTime localEnd,
  required bool isAllDay,
  required String locale,
}) {
  final date = DateFormat.yMMMEd(locale);
  final time = DateFormat.Hm(locale);
  if (isAllDay) {
    // Dernier jour inclus, par le calendrier et non par soustraction de
    // 24 h : la nuit d'un changement d'heure n'en fait pas 24.
    final last = DateTime(localEnd.year, localEnd.month, localEnd.day - 1);
    final sameDay =
        last.year == localStart.year &&
        last.month == localStart.month &&
        last.day == localStart.day;
    return sameDay
        ? date.format(localStart)
        : '${date.format(localStart)} – ${date.format(last)}';
  }
  return '${date.format(localStart)} · '
      '${time.format(localStart)}–${time.format(localEnd)}';
}

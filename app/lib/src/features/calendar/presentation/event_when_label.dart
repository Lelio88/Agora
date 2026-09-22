/// Créneau d'une instance en toutes lettres, pour les fiches (rdv importé,
/// rdv de groupe).
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:intl/intl.dart';

/// Créneau d'une instance, dans la langue [locale] : une date (ou deux, du
/// premier au dernier jour inclus) pour une journée entière, date et heures
/// sinon.
String eventWhenLabel(AgendaItem item, String locale) {
  final date = DateFormat.yMMMEd(locale);
  final time = DateFormat.Hm(locale);
  if (item.isAllDay) {
    // Dernier jour inclus, par le calendrier et non par soustraction de
    // 24 h : la nuit d'un changement d'heure n'en fait pas 24.
    final end = item.localEnd;
    final last = DateTime(end.year, end.month, end.day - 1);
    final start = item.localStart;
    final sameDay =
        last.year == start.year &&
        last.month == start.month &&
        last.day == start.day;
    return sameDay
        ? date.format(start)
        : '${date.format(start)} – ${date.format(last)}';
  }
  return '${date.format(item.localStart)} · '
      '${time.format(item.localStart)}–${time.format(item.localEnd)}';
}

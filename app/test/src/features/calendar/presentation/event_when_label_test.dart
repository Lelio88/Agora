import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/presentation/event_when_label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AgendaItem _item({
  required DateTime start,
  required DateTime end,
  bool allDay = false,
}) => AgendaItem(
  eventId: 'e',
  calendarId: 'c',
  title: 'T',
  start: start,
  end: end,
  isAllDay: allDay,
  timezone: 'Europe/Paris',
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('a one-day event shows a single date', () {
    final label = eventWhenLabel(
      _item(
        start: DateTime.utc(2026, 10, 6),
        end: DateTime.utc(2026, 10, 7),
        allDay: true,
      ),
      'fr',
    );

    expect(label, 'mar. 6 oct. 2026');
  });

  test('the night the clocks go back still makes one day', () {
    // 25 octobre 2026 : passage à l'heure d'hiver en Europe. Minuit moins
    // 24 h retomberait la veille (ou pas, selon le fuseau de la machine) ;
    // le dernier jour se calcule par le calendrier.
    final label = eventWhenLabel(
      _item(
        start: DateTime.utc(2026, 10, 25),
        end: DateTime.utc(2026, 10, 26),
        allDay: true,
      ),
      'fr',
    );

    expect(label, 'dim. 25 oct. 2026');
  });

  test('a multi-day event shows its first and last day, inclusive', () {
    final label = eventWhenLabel(
      _item(
        start: DateTime.utc(2026, 10, 12),
        end: DateTime.utc(2026, 10, 15),
        allDay: true,
      ),
      'fr',
    );

    expect(label, 'lun. 12 oct. 2026 – mer. 14 oct. 2026');
  });

  test('a timed event shows its date and hours', () {
    final start = DateTime(2026, 10, 6, 10);
    final label = eventWhenLabel(
      _item(
        start: start.toUtc(),
        end: start.add(const Duration(hours: 1)).toUtc(),
      ),
      'fr',
    );

    expect(label, 'mar. 6 oct. 2026 · 10:00–11:00');
  });
}

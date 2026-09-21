import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:flutter_test/flutter_test.dart';

AgendaItem _item({
  required DateTime start,
  required DateTime end,
  required bool isAllDay,
}) => AgendaItem(
  eventId: 'evt',
  calendarId: 'cal',
  title: 'Rdv',
  start: start,
  end: end,
  isAllDay: isAllDay,
  timezone: 'Europe/Paris',
);

void main() {
  group('local dates', () {
    test(
      'an all-day event reads its calendar date from the UTC components',
      () {
        final item = _item(
          start: DateTime.utc(2026, 10, 13),
          end: DateTime.utc(2026, 10, 14),
          isAllDay: true,
        );

        // Local midnight of the same date, whatever the device's offset:
        // toLocal() would give the eve in a negative time zone.
        expect(item.localStart, DateTime(2026, 10, 13));
        expect(item.localEnd, DateTime(2026, 10, 14));
        expect(item.localStart.isUtc, isFalse);
      },
    );

    test('a timed event is shown in the device time zone', () {
      final start = DateTime.utc(2026, 10, 13, 16);
      final item = _item(
        start: start,
        end: start.add(const Duration(hours: 1)),
        isAllDay: false,
      );

      expect(item.localStart, start.toLocal());
      expect(item.localEnd, start.add(const Duration(hours: 1)).toLocal());
    });
  });
}

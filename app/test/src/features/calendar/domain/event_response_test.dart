import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 10, 13, 16);

AgendaItem _item({String? seriesId, DateTime? originalStart}) => AgendaItem(
  eventId: 'evt-1',
  seriesId: seriesId,
  originalStart: originalStart,
  calendarId: 'cal-grp',
  title: 'Entraînement',
  start: _start,
  end: _start.add(const Duration(hours: 1)),
  isAllDay: false,
  timezone: 'Europe/Paris',
);

void main() {
  group('AgendaItem.responseKey', () {
    test('a single event is answered as a whole', () {
      expect(_item().responseKey, ResponseKey('evt-1'));
    });

    test('an occurrence of a series is answered by its slot', () {
      final item = _item(seriesId: 'evt-1', originalStart: _start);
      expect(item.responseKey, ResponseKey('evt-1', _start));
    });

    test('a modified occurrence, a row of its own, is answered as a whole', () {
      final item = _item(seriesId: 'evt-series', originalStart: _start);
      expect(item.responseKey, ResponseKey('evt-1'));
    });
  });

  test('a key is the same instant, in UTC or in local time', () {
    expect(
      ResponseKey('evt-1', _start.toLocal()),
      ResponseKey('evt-1', _start),
    );
  });

  test('ResponseStatus reads the codes the server stores', () {
    for (final status in ResponseStatus.values) {
      expect(ResponseStatus.fromCode(status.code), status);
    }
    expect(ResponseStatus.fromCode(null), isNull);
    expect(ResponseStatus.fromCode('perhaps'), isNull);
  });
}

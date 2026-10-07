import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:agora/src/features/calendar/domain/travel_candidates.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

const _mine = UserCalendar(
  id: 'cal',
  name: 'Agenda',
  kind: CalendarKind.native,
);
const _imported = UserCalendar(
  id: 'ics',
  name: 'Boulot',
  kind: CalendarKind.ics,
);
const _contact = UserCalendar(
  id: 'lea',
  name: 'Léa',
  kind: CalendarKind.native,
  isContact: true,
);
const _group = UserCalendar(
  id: 'grp',
  name: 'Coloc',
  kind: CalendarKind.native,
  groupId: 'g1',
);

AgendaItem _event({
  String? location = 'Gare de Reims',
  bool isAllDay = false,
  ResponseStatus? response,
  String? seriesId,
}) => AgendaItem(
  eventId: 'evt',
  seriesId: seriesId,
  calendarId: 'cal',
  title: 'Rdv',
  location: location,
  start: DateTime.utc(2026, 10, 8, 8),
  end: DateTime.utc(2026, 10, 8, 9),
  isAllDay: isAllDay,
  timezone: 'Europe/Paris',
  myResponse: response,
);

void main() {
  test('my own and imported events with a place get their trip', () {
    expect(needsTravel(_event(), _mine), isTrue);
    expect(needsTravel(_event(), _imported), isTrue);
  });

  test('no place, a whole day or a close one’s agenda: no trip', () {
    expect(needsTravel(_event(location: '  '), _mine), isFalse);
    expect(needsTravel(_event(location: null), _mine), isFalse);
    expect(needsTravel(_event(isAllDay: true), _mine), isFalse);
    expect(needsTravel(_event(), _contact), isFalse);
    expect(needsTravel(_event(), null), isFalse);
  });

  test('a group event only once I said I may come', () {
    expect(needsTravel(_event(response: ResponseStatus.yes), _group), isTrue);
    expect(needsTravel(_event(response: ResponseStatus.maybe), _group), isTrue);
    expect(needsTravel(_event(response: ResponseStatus.no), _group), isFalse);
    expect(needsTravel(_event(), _group), isFalse);
  });

  test('a choice is kept for the whole series', () {
    expect(travelKeyOf(_event()), 'evt');
    expect(travelKeyOf(_event(seriesId: 'serie')), 'serie');
  });
}

import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_calendar_repository.dart';
import '../../../../helpers/fake_calendars_repository.dart';

final _range = AgendaRange(
  from: DateTime.utc(2026, 10, 12),
  to: DateTime.utc(2026, 11, 2),
);

AgendaItem _item(String id, String calendarId) => AgendaItem(
  eventId: id,
  calendarId: calendarId,
  title: id,
  start: DateTime.utc(2026, 10, 14, 8),
  end: DateTime.utc(2026, 10, 14, 9),
  isAllDay: false,
  timezone: 'Europe/Paris',
);

const _personal = UserCalendar(
  id: 'cal-1',
  name: 'Agenda',
  kind: CalendarKind.native,
);
const _work = UserCalendar(
  id: 'cal-work',
  name: 'Travail',
  kind: CalendarKind.native,
);

void main() {
  late FakeCalendarRepository agenda;
  late FakeCalendarsRepository calendars;
  late ProviderContainer container;

  void start(List<UserCalendar> initial) {
    agenda = FakeCalendarRepository()
      ..seed(_item('perso', _personal.id))
      ..seed(_item('boulot', _work.id));
    calendars = FakeCalendarsRepository(initial);
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        calendarRepositoryProvider.overrideWithValue(agenda),
        calendarsRepositoryProvider.overrideWithValue(calendars),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(agenda.dispose);
  }

  Future<List<String>> visibleTitles() async {
    final sub = container.listen(visibleAgendaProvider(_range), (_, _) {});
    addTearDown(sub.close);
    final items = await container.read(visibleAgendaProvider(_range).future);
    return [for (final item in items) item.title];
  }

  test('a hidden calendar disappears from the visible agenda', () async {
    start([_personal, _work.copyWith(hidden: true)]);

    expect(await visibleTitles(), ['perso']);
  });

  test('showing a calendar again brings its events back', () async {
    start([_personal, _work.copyWith(hidden: true)]);
    expect(await visibleTitles(), ['perso']);

    await container
        .read(calendarsServiceProvider)
        .setHidden(_work.id, hidden: false);

    expect(await visibleTitles(), containsAll(['perso', 'boulot']));
  });

  test(
    'the default calendar is the oldest one the user can write to',
    () async {
      start([
        const UserCalendar(id: 'cal-ics', name: 'Club', kind: CalendarKind.ics),
        _personal,
        _work,
      ]);

      expect(await container.read(defaultCalendarIdProvider.future), 'cal-1');
    },
  );

  test('deleting a calendar refreshes the list', () async {
    start([_personal, _work]);
    await container.read(calendarsProvider.future);

    await container.read(calendarsServiceProvider).delete(_work.id);

    final ids = [
      for (final c in await container.read(calendarsProvider.future)) c.id,
    ];
    expect(ids, ['cal-1']);
  });
}

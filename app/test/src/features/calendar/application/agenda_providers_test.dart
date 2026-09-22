import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_calendar_repository.dart';
import '../../../../helpers/fakes.dart';

final _from = DateTime.utc(2026, 10, 12);
final _to = DateTime.utc(2026, 11, 2);
final _range = AgendaRange(from: _from, to: _to);

AgendaItem _single({String id = 'evt-1', String title = 'Dentiste'}) =>
    AgendaItem(
      eventId: id,
      calendarId: FakeCalendarRepository.calendarId,
      title: title,
      start: DateTime.utc(2026, 10, 14, 8),
      end: DateTime.utc(2026, 10, 14, 9),
      isAllDay: false,
      timezone: 'Europe/Paris',
    );

EventDraft _draft({RecurrenceRule? recurrence, String title = 'Yoga'}) =>
    EventDraft(
      calendarId: FakeCalendarRepository.calendarId,
      title: title,
      start: DateTime.utc(2026, 10, 13, 16),
      end: DateTime.utc(2026, 10, 13, 17),
      timezone: 'Europe/Paris',
      recurrence: recurrence,
    );

void main() {
  late FakeCalendarRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeCalendarRepository();
    // Le temps réel de l'agenda ne s'ouvre qu'avec un compte connecté.
    final auth = FakeAuthRepository(
      signedInAs: const AppUser(
        id: FakeAuthRepository.userId,
        email: 'zoe@test.local',
      ),
    );
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        calendarRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repository.dispose);
    addTearDown(auth.dispose);
  });

  /// L'agenda tel qu'un écran le verrait : écouté, donc rafraîchi à chaque
  /// changement signalé par le dépôt.
  Future<List<AgendaItem>> agenda() async {
    final sub = container.listen(agendaProvider(_range), (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    return container.read(agendaProvider(_range).future);
  }

  test('agendaProvider lists the items of its range', () async {
    repository.seed(_single());

    final items = await agenda();

    expect(items.map((i) => i.title), ['Dentiste']);
  });

  test('agendaProvider reloads when the repository signals a change', () async {
    await agenda();
    expect(repository.calls.where((c) => c == 'fetchAgenda').length, 1);

    await container.read(calendarServiceProvider).create(_draft());
    final items = await agenda();

    expect(items.map((i) => i.title), contains('Yoga'));
    // L'action invalide l'agenda, puis le tick temps réel le relit encore :
    // deux relectures, jamais moins.
    expect(
      repository.calls.where((c) => c == 'fetchAgenda').length,
      greaterThanOrEqualTo(2),
    );
  });

  test('creating a weekly series shows one occurrence per week', () async {
    await container
        .read(calendarServiceProvider)
        .create(
          _draft(recurrence: const RecurrenceRule(frequency: Frequency.weekly)),
        );

    final items = await agenda();

    expect(items.length, 3);
    expect(items.every((i) => i.kind == InstanceKind.seriesOccurrence), isTrue);
  });

  test('editing one occurrence detaches it from its series', () async {
    final service = container.read(calendarServiceProvider);
    await service.create(
      _draft(recurrence: const RecurrenceRule(frequency: Frequency.weekly)),
    );
    final second = (await agenda())[1];

    await service.save(
      target: EditTarget.occurrence(second),
      draft: _draft(title: 'Yoga (décalé)').copyWith(
        start: second.start.add(const Duration(hours: 2)),
        end: second.end.add(const Duration(hours: 2)),
      ),
    );

    final items = await agenda();
    final modified = items.singleWhere((i) => i.title == 'Yoga (décalé)');
    expect(modified.kind, InstanceKind.modifiedOccurrence);
    expect(modified.originalStart, second.originalStart);
    expect(items.where((i) => i.title == 'Yoga').length, 2);
  });

  test('editing the whole series renames every occurrence', () async {
    final service = container.read(calendarServiceProvider);
    await service.create(
      _draft(recurrence: const RecurrenceRule(frequency: Frequency.weekly)),
    );
    final first = (await agenda()).first;

    await service.save(
      target: EditTarget.series(first),
      draft: _draft(
        title: 'Yoga doux',
        recurrence: const RecurrenceRule(frequency: Frequency.weekly),
      ),
    );

    final items = await agenda();
    expect(items.every((i) => i.title == 'Yoga doux'), isTrue);
    expect(repository.writes.last, 'updateSeries');
  });

  test('renaming the series from a later occurrence keeps its start', () async {
    final service = container.read(calendarServiceProvider);
    await service.create(
      _draft(recurrence: const RecurrenceRule(frequency: Frequency.weekly)),
    );
    final third = (await agenda())[2];

    await service.save(
      target: EditTarget.series(third),
      draft: _draft(
        title: 'Yoga doux',
        recurrence: const RecurrenceRule(frequency: Frequency.weekly),
      ).copyWith(start: third.start, end: third.end),
    );

    final update = repository.lastSeriesUpdate!;
    expect(update.occurrenceStart, third.start);
    expect(update.draft.start, third.start, reason: 'no shift requested');
    expect((await agenda()).first.start, DateTime.utc(2026, 10, 13, 16));
  });

  test('from a moved occurrence, unchanged dates keep the schedule', () async {
    final service = container.read(calendarServiceProvider);
    await service.create(
      _draft(recurrence: const RecurrenceRule(frequency: Frequency.weekly)),
    );
    final second = (await agenda())[1];
    await service.save(
      target: EditTarget.occurrence(second),
      draft: _draft(title: 'Yoga (décalé)').copyWith(
        start: second.start.add(const Duration(hours: 2)),
        end: second.end.add(const Duration(hours: 2)),
      ),
    );
    final moved = (await agenda()).firstWhere(
      (i) => i.kind == InstanceKind.modifiedOccurrence,
    );

    await service.save(
      target: EditTarget.series(moved),
      draft: _draft(
        title: 'Yoga doux',
        recurrence: const RecurrenceRule(frequency: Frequency.weekly),
      ).copyWith(start: moved.start, end: moved.end),
    );

    final update = repository.lastSeriesUpdate!;
    expect(update.occurrenceStart, moved.originalStart);
    expect(
      update.draft.start,
      moved.originalStart,
      reason: 'the series keeps its own time, not the moved one',
    );
  });

  test('untouched weekdays follow the series shift', () async {
    const tuesdays = RecurrenceRule(
      frequency: Frequency.weekly,
      weekdays: {DateTime.tuesday},
    );
    final service = container.read(calendarServiceProvider);
    await service.create(_draft(recurrence: tuesdays));
    final first = (await agenda()).first;

    await service.save(
      target: EditTarget.series(first),
      draft: _draft(recurrence: tuesdays).copyWith(
        start: first.start.add(const Duration(days: 1)),
        end: first.end.add(const Duration(days: 1)),
      ),
    );

    final update = repository.lastSeriesUpdate!;
    expect(update.followWeekdays, isTrue);
    expect(update.draft.recurrence!.weekdays, {
      DateTime.tuesday,
    }, reason: 'the server shifts them, in the series time zone');
  });

  test('weekdays the user changed are kept as chosen', () async {
    final service = container.read(calendarServiceProvider);
    await service.create(
      _draft(
        recurrence: const RecurrenceRule(
          frequency: Frequency.weekly,
          weekdays: {DateTime.tuesday},
        ),
      ),
    );
    final first = (await agenda()).first;

    await service.save(
      target: EditTarget.series(first),
      draft:
          _draft(
            recurrence: const RecurrenceRule(
              frequency: Frequency.weekly,
              weekdays: {DateTime.thursday},
            ),
          ).copyWith(
            start: first.start.add(const Duration(days: 1)),
            end: first.end.add(const Duration(days: 1)),
          ),
    );

    final update = repository.lastSeriesUpdate!;
    expect(update.followWeekdays, isFalse);
    expect(update.draft.recurrence!.weekdays, {DateTime.thursday});
  });

  test('deleting one occurrence keeps the others', () async {
    final service = container.read(calendarServiceProvider);
    await service.create(
      _draft(recurrence: const RecurrenceRule(frequency: Frequency.weekly)),
    );
    final second = (await agenda())[1];

    await service.delete(EditTarget.occurrence(second));

    final items = await agenda();
    expect(items.length, 2);
    expect(items.any((i) => i.start == second.start), isFalse);
    expect(repository.writes.last, 'deleteOccurrence');
  });

  test('deleting the series removes every occurrence', () async {
    final service = container.read(calendarServiceProvider);
    await service.create(
      _draft(recurrence: const RecurrenceRule(frequency: Frequency.weekly)),
    );
    final first = (await agenda()).first;

    await service.delete(EditTarget.series(first));

    expect(await agenda(), isEmpty);
    expect(repository.writes.last, 'deleteEvent');
  });

  test('a single event is always edited as itself', () async {
    repository.seed(_single());
    final item = (await agenda()).single;

    await container
        .read(calendarServiceProvider)
        .save(
          target: EditTarget.series(item),
          draft: _draft(title: 'Dentiste (reporté)'),
        );

    expect(repository.writes.last, 'updateEvent');
  });
}

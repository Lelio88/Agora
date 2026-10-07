import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/similar_events.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime.utc(2026, 10, 5, 6);

AgendaItem _course({String? seriesId, String eventId = 'evt-td'}) => AgendaItem(
  eventId: eventId,
  seriesId: seriesId,
  originalStart: seriesId == null ? null : _start,
  calendarId: 'cal-perso',
  title: 'NF19 — TD',
  location: 'UTT',
  description: 'Séance 1',
  start: _start,
  end: _start.add(const Duration(hours: 2)),
  isAllDay: false,
  timezone: 'Europe/Paris',
);

void main() {
  group('similarChanges', () {
    test('nothing changed: nothing to copy', () {
      final item = _course();

      expect(similarChanges(item, EventDraft.fromItem(item)), isEmpty);
    });

    test('blank text and spaces count as unchanged, as the server stores '
        'them', () {
      final item = _course();
      final draft = EventDraft.fromItem(item)
          .copyWith(title: '  NF19 — TD ', location: () => ' UTT ');

      expect(similarChanges(item, draft), isEmpty);
    });

    test('a new location is the only field to copy', () {
      final item = _course();
      final draft = EventDraft.fromItem(item)
          .copyWith(location: () => '12 rue Marie Curie, 10300 Troyes');

      expect(similarChanges(item, draft), {SimilarField.location});
    });

    test('dates and times are never copied', () {
      final item = _course();
      final draft = EventDraft.fromItem(item).copyWith(
        start: _start.add(const Duration(days: 1, hours: 2)),
        end: _start.add(const Duration(days: 1, hours: 5)),
      );

      expect(similarChanges(item, draft), isEmpty);
    });

    test('every changed field is listed, title first', () {
      final item = _course();
      final draft = EventDraft.fromItem(item).copyWith(
        calendarId: 'cal-fac',
        title: 'NF19 — TD (amphi)',
        description: () => '',
        visibility: () => EventVisibility.busy,
      );

      expect(similarChanges(item, draft).toList(), [
        SimilarField.title,
        SimilarField.description,
        SimilarField.visibility,
        SimilarField.calendar,
      ]);
    });
  });

  group('canHaveSimilar', () {
    test('only a single event has look-alikes', () {
      expect(canHaveSimilar(_course()), isTrue);
      expect(canHaveSimilar(_course(seriesId: 'evt-td')), isFalse);
      expect(
        canHaveSimilar(_course(seriesId: 'serie', eventId: 'evt-x')),
        isFalse,
      );
    });
  });
}

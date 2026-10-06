import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/features/groups/domain/member_agenda.dart';
import 'package:flutter_test/flutter_test.dart';

final _ten = DateTime.utc(2026, 10, 12, 8);
final _noon = DateTime.utc(2026, 10, 12, 10);

GroupAgendaItem _slot({
  String? userId = 'u-lea',
  ShareLevel level = ShareLevel.busy,
  String? eventId,
  String? title,
  DateTime? start,
  DateTime? end,
  bool isGroupEvent = false,
}) => GroupAgendaItem(
  level: level,
  start: start ?? _ten,
  end: end ?? _noon,
  isAllDay: false,
  userId: userId,
  eventId: eventId,
  title: title,
  isGroupEvent: isGroupEvent,
);

void main() {
  group('memberSharedAgenda', () {
    test('keeps only the slots of that member', () {
      final result = memberSharedAgenda('u-lea', [
        [
          _slot(),
          _slot(userId: 'u-max'),
          _slot(userId: null, isGroupEvent: true, title: 'Repas'),
        ],
      ]);

      expect(result, hasLength(1));
      expect(result.single.userId, 'u-lea');
    });

    test('a slot seen in two groups shows once, in its most detail', () {
      final details = _slot(
        level: ShareLevel.details,
        eventId: 'evt-1',
        title: 'Piscine',
      );
      final result = memberSharedAgenda('u-lea', [
        [_slot()],
        [details],
      ]);

      expect(result.single.title, 'Piscine');
    });

    test('the same detailed event in two groups shows once', () {
      final details = _slot(
        level: ShareLevel.details,
        eventId: 'evt-1',
        title: 'Piscine',
      );
      expect(
        memberSharedAgenda('u-lea', [
          [details],
          [details],
        ]),
        hasLength(1),
      );
    });

    test('distinct slots stay, soonest first', () {
      final later = _slot(
        start: DateTime.utc(2026, 10, 13, 8),
        end: DateTime.utc(2026, 10, 13, 9),
      );
      final result = memberSharedAgenda('u-lea', [
        [later],
        [_slot()],
      ]);

      expect(result.map((s) => s.start), [_ten, later.start]);
    });
  });
}

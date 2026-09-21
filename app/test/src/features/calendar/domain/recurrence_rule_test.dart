import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurrenceRule.toRRule', () {
    for (final (rule, expected) in [
      (const RecurrenceRule(frequency: Frequency.daily), 'FREQ=DAILY'),
      (const RecurrenceRule(frequency: Frequency.weekly), 'FREQ=WEEKLY'),
      (
        const RecurrenceRule(
          frequency: Frequency.weekly,
          interval: 2,
          weekdays: {DateTime.monday, DateTime.friday},
        ),
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR',
      ),
      (
        RecurrenceRule(
          frequency: Frequency.monthly,
          until: DateTime.utc(2026, 12, 31),
        ),
        'FREQ=MONTHLY;UNTIL=20261231T000000Z',
      ),
      (
        const RecurrenceRule(frequency: Frequency.yearly, count: 5),
        'FREQ=YEARLY;COUNT=5',
      ),
    ]) {
      test('serialises to $expected', () => expect(rule.toRRule(), expected));
    }
  });

  group('RecurrenceRule.parse', () {
    test('round-trips every field', () {
      const source = 'FREQ=WEEKLY;INTERVAL=3;BYDAY=TU,TH;COUNT=10';

      expect(RecurrenceRule.parse(source)?.toRRule(), source);
    });

    test('reads UNTIL as a UTC instant', () {
      final rule = RecurrenceRule.parse('FREQ=DAILY;UNTIL=20261231T000000Z');

      expect(rule?.until, DateTime.utc(2026, 12, 31));
    });

    test('returns null for a rule the editor cannot represent', () {
      expect(RecurrenceRule.parse('FREQ=WEEKLY;BYMONTHDAY=13'), isNull);
      expect(RecurrenceRule.parse('FREQ=HOURLY'), isNull);
      expect(RecurrenceRule.parse('nonsense'), isNull);
    });

    test('ignores an unknown weekday code', () {
      expect(RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=XX'), isNull);
    });
  });
}

import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('looksLikeFeedUrl', () {
    const accepted = [
      'https://calendar.google.com/calendar/ical/x/private-abc/basic.ics',
      'webcal://p42-caldav.icloud.com/published/2/abc',
      'WEBCAL://example.com/a.ics',
      '  https://example.com/a.ics  ',
      'https://example.com',
    ];
    const refused = [
      '',
      'http://example.com/a.ics',
      'ftp://example.com/a.ics',
      'https://',
      'https://user:secret@example.com/a.ics',
      'https://example.com/a b.ics',
      'example.com/a.ics',
    ];
    for (final url in accepted) {
      test('accepts "$url"', () => expect(looksLikeFeedUrl(url), isTrue));
    }
    for (final url in refused) {
      test('refuses "$url"', () => expect(looksLikeFeedUrl(url), isFalse));
    }
    test('refuses a link longer than the server allows', () {
      final long = 'https://example.com/${'a' * 2048}';
      expect(looksLikeFeedUrl(long), isFalse);
    });
  });

  group('FeedSyncError.fromCode', () {
    test('reads every code the worker records', () {
      for (final error in FeedSyncError.values) {
        expect(FeedSyncError.fromCode(error.code), error);
      }
    });

    test('no code, no error', () {
      expect(FeedSyncError.fromCode(null), isNull);
    });

    test('an unknown code from a newer worker stays an error', () {
      expect(FeedSyncError.fromCode('rate_limited'), FeedSyncError.unknown);
    });
  });

  test('an imported draft never prints its link', () {
    const draft = ImportedCalendarDraft(
      name: 'Boulot',
      url: 'https://example.com/private-7f3a9c.ics',
    );
    expect('$draft', isNot(contains('private-7f3a9c')));
  });
}

import 'package:agora/src/features/calendar/domain/event_link.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _params([Map<String, String> overrides = const {}]) => {
  'de': 'arpente',
  'titre': 'Sortie Caen — Caen',
  'debut': '2026-10-10T14:00:00+02:00',
  'duree': '150',
  ...overrides,
};

void main() {
  group('parseEventLink', () {
    test('reads a rdv prepared in Arpente', () {
      final link = parseEventLink(
        _params({
          'lieu': 'Château de Caen',
          'description': 'Parcours de 2 lieux.\n\n1. Château\n2. Abbaye',
          'groupe': 'wxyz2345',
        }),
      );

      expect(link, isNotNull);
      expect(link!.sender, EventLinkSender.arpente);
      expect(link.title, 'Sortie Caen — Caen');
      expect(link.start, DateTime.utc(2026, 10, 10, 12));
      expect(link.end, DateTime.utc(2026, 10, 10, 14, 30));
      expect(link.location, 'Château de Caen');
      expect(link.description, 'Parcours de 2 lieux.\n\n1. Château\n2. Abbaye');
      expect(link.groupCode, 'WXYZ2345');
    });

    test('an instant in UTC is read as such', () {
      final link = parseEventLink(_params({'debut': '2026-10-10T12:00:00Z'}));
      expect(link!.start, DateTime.utc(2026, 10, 10, 12));
    });

    final invalid = <String, Map<String, String>>{
      'unknown sender': _params({'de': 'lumis'}),
      'no sender': {..._params()}..remove('de'),
      'no title': {..._params()}..remove('titre'),
      'a title of nothing but hidden characters': _params({
        'titre': '\u202e\u200b ',
      }),
      'a start without offset': _params({'debut': '2026-10-10T14:00:00'}),
      'an unreadable start': _params({'debut': 'samedi 14 h'}),
      'no duration': {..._params()}..remove('duree'),
      'a duration under 5 minutes': _params({'duree': '4'}),
      'a duration over a day': _params({'duree': '1441'}),
      'a duration that is not a whole number': _params({'duree': '90.5'}),
    };
    invalid.forEach((reason, params) {
      test('ignores a link with $reason', () {
        expect(parseEventLink(params), isNull);
      });
    });

    test('an implausible group code only drops the preselection', () {
      final link = parseEventLink(_params({'groupe': 'ABC0EF12'}));
      expect(link, isNotNull);
      expect(link!.groupCode, isNull);
    });

    test('texts are cleaned and cut to the protocol lengths', () {
      final link = parseEventLink(
        _params({
          'titre': 'Sortie\u202e  à\tCaen',
          'lieu': 'L' * 400,
          'description': 'a\r\nb\u0007c${'d' * 2100}',
        }),
      );

      expect(link!.title, 'Sortie à Caen');
      expect(link.location!.length, 300);
      expect(link.description, startsWith('a\nb c'));
      expect(link.description!.runes.length, 2000);
    });

    test('empty optional texts are dropped', () {
      final link = parseEventLink(_params({'lieu': ' ', 'description': ''}));
      expect(link!.location, isNull);
      expect(link.description, isNull);
    });
  });
}

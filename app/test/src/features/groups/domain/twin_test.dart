import 'dart:math';

import 'package:agora/src/features/groups/domain/twin.dart';
import 'package:flutter_test/flutter_test.dart';

const _state = 'abcdefghijklmnop_-12';

void main() {
  group('parseTwinLink', () {
    test('reads a request from Arpente', () {
      final link = parseTwinLink({
        'de': 'arpente',
        'code': 'abc234',
        'nom': 'Sortie à Caen',
        'etat': _state,
      });

      expect(link, isA<TwinRequest>());
      final request = link! as TwinRequest;
      expect(request.app, TwinApp.arpente);
      expect(request.remoteCode, 'ABC234');
      expect(request.name, 'Sortie à Caen');
      expect(request.state, _state);
    });

    test('reads a response: « pour » carries our invitation code', () {
      final link = parseTwinLink({
        'de': 'arpente',
        'code': 'ABC234',
        'pour': 'wxyz2345',
        'etat': _state,
      });

      expect(link, isA<TwinResponse>());
      final response = link! as TwinResponse;
      expect(response.remoteCode, 'ABC234');
      expect(response.forCode, 'WXYZ2345');
    });

    final invalid = <String, Map<String, String>>{
      'unknown app': {'de': 'lumis', 'code': 'ABC234', 'etat': _state},
      'DewDrop code too short': {
        'de': 'dewdrop',
        'code': 'ABC234',
        'etat': _state,
      },
      'no app': {'code': 'ABC234', 'etat': _state},
      'Arpente code too long': {
        'de': 'arpente',
        'code': 'ABC2345',
        'etat': _state,
      },
      'code outside the alphabet': {
        'de': 'arpente',
        'code': 'ABC0EF',
        'etat': _state,
      },
      'no state': {'de': 'arpente', 'code': 'ABC234'},
      'state too short': {'de': 'arpente', 'code': 'ABC234', 'etat': 'abc'},
      'state with forbidden characters': {
        'de': 'arpente',
        'code': 'ABC234',
        'etat': 'abcdefghijklmnop<script>',
      },
      'response for an implausible invitation': {
        'de': 'arpente',
        'code': 'ABC234',
        'pour': 'ABC234',
        'etat': _state,
      },
    };
    for (final MapEntry(key: reason, value: params) in invalid.entries) {
      test('refuses a link with $reason', () {
        expect(parseTwinLink(params), isNull);
      });
    }

    test('a request without a usable name keeps no name', () {
      final link =
          parseTwinLink({
                'de': 'arpente',
                'code': 'ABC234',
                'nom': ' \u0007\u202e ',
                'etat': _state,
              })!
              as TwinRequest;
      expect(link.name, isNull);
    });
  });

  group('cleanTwinName', () {
    test('drops control and bidi characters and folds spaces', () {
      expect(
        cleanTwinName('  Sortie\u0000 \u202eCaen\n\tdimanche  '),
        'Sortie Caen dimanche',
      );
    });

    test('keeps at most 60 characters', () {
      expect(cleanTwinName('é' * 80)!.runes.length, 60);
    });
  });

  group('links built for Arpente', () {
    test('a request carries our invitation in the fragment', () {
      final uri = twinRequestUri(
        TwinApp.arpente,
        inviteCode: 'WXYZ2345',
        name: 'Sortie Caen',
        state: _state,
      );

      expect(uri.origin, 'https://arpente.heianenterprise.com');
      expect(uri.path, '/jumeler.html');
      // Le code est un secret : jamais dans la requête, que l'hébergeur
      // journaliserait.
      expect(uri.query, isEmpty);
      expect(Uri.splitQueryString(uri.fragment), {
        'de': 'agora',
        'code': 'WXYZ2345',
        'nom': 'Sortie Caen',
        'etat': _state,
      });
    });

    test('a response names the group it answers', () {
      final uri = twinResponseUri(
        TwinApp.arpente,
        inviteCode: 'WXYZ2345',
        forCode: 'ABC234',
        state: _state,
      );

      expect(uri.query, isEmpty);
      expect(Uri.splitQueryString(uri.fragment), {
        'de': 'agora',
        'code': 'WXYZ2345',
        'pour': 'ABC234',
        'etat': _state,
      });
    });

    test('joining the twin opens its invitation page', () {
      expect(
        TwinApp.arpente.joinUri('ABC234').toString(),
        'https://arpente.heianenterprise.com/rejoindre.html#code=ABC234',
      );
    });
  });

  group('DewDrop', () {
    test('reads a request from DewDrop: a circle code has 8 characters', () {
      final link = parseTwinLink({
        'de': 'dewdrop',
        'code': 'abcd2345',
        'nom': 'Les copains',
        'etat': _state,
      });

      expect(link, isA<TwinRequest>());
      expect(link!.app, TwinApp.dewdrop);
      expect(link.remoteCode, 'ABCD2345');
    });

    test('joining a DewDrop circle is a request to its creator', () {
      expect(TwinApp.dewdrop.joinIsRequest, isTrue);
      expect(TwinApp.arpente.joinIsRequest, isFalse);
    });

    test('links point to DewDrop pages, parameters in the fragment', () {
      final uri = twinRequestUri(
        TwinApp.dewdrop,
        inviteCode: 'WXYZ2345',
        name: 'Les copains',
        state: _state,
      );

      expect(uri.origin, 'https://dewdrop.heianenterprise.com');
      expect(uri.path, '/jumeler.html');
      expect(uri.query, isEmpty);
      expect(Uri.splitQueryString(uri.fragment)['de'], 'agora');
      expect(
        TwinApp.dewdrop.joinUri('ABCD2345').toString(),
        'https://dewdrop.heianenterprise.com/rejoindre.html#code=ABCD2345',
      );
    });
  });

  test('a new state is a 22-character URL-safe token', () {
    final state = newTwinState(Random(1));
    expect(state, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
    expect(newTwinState(Random(2)), isNot(state));
  });
}

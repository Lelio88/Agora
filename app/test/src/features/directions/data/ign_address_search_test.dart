import 'dart:convert';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/directions/data/ign_address_search.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Une réponse de la Géoplateforme, telle que relevée le 2026-10-07.
const _reims = {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [4.031847, 49.257517],
      },
      'properties': {
        'label': "1 Place de l'Hôtel de Ville 51100 Reims",
        'score': 0.97,
        'type': 'housenumber',
      },
    },
    // Sans point : ignorée plutôt que d'échouer.
    {
      'type': 'Feature',
      'geometry': null,
      'properties': {'label': 'Nulle part'},
    },
  ],
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('asks the IGN for addresses and reads their label and point', () async {
    final asked = <Uri>[];
    final search = IgnAddressSearch(
      MockClient((request) async {
        asked.add(request.url);
        return _json(_reims);
      }),
    );

    final found = await search.search('  1 place de l’hôtel de ville reims ');

    expect(found, const [
      Address(
        label: "1 Place de l'Hôtel de Ville 51100 Reims",
        longitude: 4.031847,
        latitude: 49.257517,
      ),
    ]);
    final url = asked.single;
    expect(url.host, 'data.geopf.fr');
    expect(url.path, '/geocodage/search');
    expect(url.queryParameters['q'], '1 place de l’hôtel de ville reims');
    expect(url.queryParameters['index'], 'address');
    expect(url.queryParameters['limit'], '5');
  });

  test('does not ask while the text is too short to search', () async {
    var calls = 0;
    final search = IgnAddressSearch(
      MockClient((_) async {
        calls++;
        return _json(_reims);
      }),
    );

    expect(await search.search(' 12 '), isEmpty);
    expect(await search.search('-- rue'), isEmpty);
    expect(calls, 0);
  });

  test('too many requests is a rate limit', () async {
    final search = IgnAddressSearch(
      MockClient((_) async => _json({'code': 429}, 429)),
    );

    await expectLater(
      search.search('rue de Vesle'),
      throwsA(isA<RateLimitedException>()),
    );
  });

  test('a refused or broken answer is an unknown error', () async {
    for (final response in [
      _json({'code': 500}, 500),
      http.Response('<html>', 200),
      _json({'features': 'none'}),
    ]) {
      final search = IgnAddressSearch(MockClient((_) async => response));

      await expectLater(
        search.search('rue de Vesle'),
        throwsA(isA<UnknownException>()),
      );
    }
  });

  group('the place of an event', () {
    // Relevés le 2026-10-07 : un lieu (poi) porte des listes, une adresse
    // des chaînes.
    Map<String, Object?> poi(
      String name, {
      required double score,
      required String city,
      required String postcode,
    }) => {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [4.0244, 49.2597],
      },
      'properties': {
        'name': [name],
        'city': [city],
        'postcode': [postcode],
        'score': score,
        '_type': 'poi',
      },
    };

    IgnAddressSearch answering(
      List<Map<String, Object?>> features, [
      List<Uri>? asked,
    ]) => IgnAddressSearch(
      MockClient((request) async {
        asked?.add(request.url);
        return _json({'type': 'FeatureCollection', 'features': features});
      }),
    );

    test('is the first sure match, among addresses and places', () async {
      final asked = <Uri>[];
      final search = answering([
        poi('Gare de Reims', score: 0.85, city: 'Reims', postcode: '51100'),
      ], asked);

      expect(
        await search.locate(' Gare de Reims '),
        const Address(
          label: 'Gare de Reims, 51100 Reims',
          longitude: 4.0244,
          latitude: 49.2597,
        ),
      );
      expect(asked.single.queryParameters['q'], 'Gare de Reims');
      expect(asked.single.queryParameters['index'], 'address,poi');
    });

    test('skips what the text does not name, or too unsure', () async {
      final search = answering([
        // « Chez Paul » : une rue d'Orléat, à l'autre bout de la France.
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [3.4, 45.9],
          },
          'properties': {
            'label': 'Chez Paul 63190 Orléat',
            'city': 'Orléat',
            'postcode': '63190',
            'score': 0.95,
            '_type': 'address',
          },
        },
        poi(
          'Halles du Boulingrin',
          score: 0.41,
          city: 'Reims',
          postcode: '51100',
        ),
      ]);

      expect(await search.locate('Chez Paul, Reims'), isNull);
    });

    test('takes a later result when the first is not sure', () async {
      final search = answering([
        poi('Gare', score: 0.9, city: 'Épernay', postcode: '51200'),
        poi('Gare de Reims', score: 0.8, city: 'Reims', postcode: '51100'),
      ]);

      expect(
        (await search.locate('Gare de Reims'))?.label,
        startsWith('Gare de Reims'),
      );
    });

    test('asks nothing for a text that cannot be searched', () async {
      final asked = <Uri>[];
      final search = answering(const [], asked);

      expect(await search.locate('Zo'), isNull);
      expect(asked, isEmpty);
    });
  });

  test('no connection is a network error', () async {
    final search = IgnAddressSearch(
      MockClient((_) async => throw http.ClientException('Failed host lookup')),
    );

    await expectLater(
      search.search('rue de Vesle'),
      throwsA(isA<NetworkException>()),
    );
  });
}

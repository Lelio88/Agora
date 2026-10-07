/// [AddressSearch] adossée au service d'adresses de la Géoplateforme de
/// l'IGN (`data.geopf.fr/geocodage/search`) : l'index « address » (la Base
/// Adresse Nationale) pour le domicile, « address,poi » (plus les lieux de
/// la BD TOPO : gares, mairies, stades…) pour le lieu d'un rdv.
///
/// Choix non évidents :
/// - service public, gratuit et sans clé : l'app l'appelle directement, sans
///   passer par le serveur d'Agora. Il limite les appels à 50 par seconde et
///   par adresse IP ; l'écran attend une pause de la frappe avant d'appeler ;
/// - la France seulement ;
/// - le lieu d'un rdv n'est retenu que s'il est assez sûr ([_minScore]) et
///   que le texte nomme sa commune ou son code postal (`mentionsPlace`) : le
///   service trouve presque toujours quelque chose, même pour « Bureau » ;
/// - une adresse (BAN) porte des chaînes, un lieu (BD TOPO) des listes ;
/// - une réponse illisible, ou une adresse sans point ou sans libellé, ne
///   devient jamais une adresse à moitié remplie : la première est une
///   erreur, la seconde est sautée.
///
/// Invariant : seules des `AppException` en sortent, et ni le texte cherché
/// ni l'adresse trouvée n'y figurent.
library;

import 'dart:convert';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/network_errors.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:http/http.dart' as http;

final class IgnAddressSearch implements AddressSearch {
  const IgnAddressSearch(this._client);

  final http.Client _client;

  static const _limit = 5;
  static const _timeout = Duration(seconds: 10);

  /// Sous ce score, le service devine plus qu'il ne trouve.
  static const _minScore = 0.5;

  @override
  Future<List<Address>> search(String text) async {
    if (!isSearchableAddress(text)) return const [];
    final features = await _features(text.trim(), 'address');
    return [for (final feature in features) feature.address];
  }

  @override
  Future<Address?> locate(String place) async {
    if (!isSearchableAddress(place)) return null;
    final text = place.trim();
    for (final (:address, :score, :names) in await _features(
      text,
      'address,poi',
    )) {
      if (score >= _minScore &&
          mentionsPlace(
            text,
            cities: names.cities,
            postcodes: names.postcodes,
          )) {
        return address;
      }
    }
    return null;
  }

  Future<List<_Feature>> _features(String text, String index) async {
    final url = Uri.https('data.geopf.fr', '/geocodage/search', {
      'q': text,
      'index': index,
      'limit': '$_limit',
    });
    final http.Response response;
    try {
      response = await _client.get(url).timeout(_timeout);
    } on Exception catch (error) {
      throw looksLikeNetworkError(error.toString())
          ? const NetworkException()
          : const UnknownException();
    }
    if (response.statusCode == 429) throw const RateLimitedException();
    if (response.statusCode != 200) throw const UnknownException();
    try {
      return _featuresIn(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      throw const UnknownException();
    }
  }

  /// Les résultats d'une réponse GeoJSON ; [FormatException] si ce n'en est
  /// pas une.
  static List<_Feature> _featuresIn(Object? json) {
    if (json case {'features': final List<Object?> features}) {
      return [
        for (final feature in features)
          if (feature case {
            'geometry': {'coordinates': [final num lon, final num lat, ...]},
            'properties': final Map<String, Object?> properties,
          })
            if (_labelOf(properties) case final label?)
              (
                address: Address(
                  label: label,
                  longitude: lon.toDouble(),
                  latitude: lat.toDouble(),
                ),
                score: (properties['score'] as num?)?.toDouble() ?? 0,
                names: (
                  cities: _strings(properties['city']),
                  postcodes: _strings(properties['postcode']),
                ),
              ),
      ];
    }
    throw const FormatException('GeoJSON without features');
  }

  /// Le libellé d'une adresse, ou « nom, code postal commune » d'un lieu.
  static String? _labelOf(Map<String, Object?> properties) {
    if (properties['label'] case final String label) return label;
    final name = _strings(properties['name']).firstOrNull;
    if (name == null) return null;
    final where = [
      ..._strings(properties['postcode']).take(1),
      ..._strings(properties['city']).take(1),
    ].join(' ');
    return where.isEmpty ? name : '$name, $where';
  }

  /// Une chaîne ou une liste de chaînes, en liste.
  static List<String> _strings(Object? value) => switch (value) {
    final String text => [text],
    final List<Object?> list => list.whereType<String>().toList(),
    _ => const [],
  };
}

/// Un résultat : l'adresse, sa certitude, et les noms qui la situent.
typedef _Feature = ({
  Address address,
  double score,
  ({List<String> cities, List<String> postcodes}) names,
});

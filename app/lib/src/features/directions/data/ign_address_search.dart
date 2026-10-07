/// [AddressSearch] adossée au service d'adresses de la Géoplateforme de
/// l'IGN (`data.geopf.fr/geocodage/search`, index « address » : la Base
/// Adresse Nationale).
///
/// Choix non évidents :
/// - service public, gratuit et sans clé : l'app l'appelle directement, sans
///   passer par le serveur d'Agora. Il limite les appels à 50 par seconde et
///   par adresse IP ; l'écran attend une pause de la frappe avant d'appeler ;
/// - la France seulement (adresses de la BAN) ;
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
import 'package:http/http.dart' as http;

final class IgnAddressSearch implements AddressSearch {
  const IgnAddressSearch(this._client);

  final http.Client _client;

  static const _limit = 5;
  static const _timeout = Duration(seconds: 10);

  @override
  Future<List<Address>> search(String text) async {
    if (!isSearchableAddress(text)) return const [];
    final url = Uri.https('data.geopf.fr', '/geocodage/search', {
      'q': text.trim(),
      'index': 'address',
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
      return _addressesIn(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      throw const UnknownException();
    }
  }

  /// Les adresses d'une réponse GeoJSON ; [FormatException] si ce n'en est
  /// pas une.
  static List<Address> _addressesIn(Object? json) {
    if (json case {'features': final List<Object?> features}) {
      return [
        for (final feature in features)
          if (feature case {
            'geometry': {'coordinates': [final num lon, final num lat, ...]},
            'properties': {'label': final String label},
          })
            Address(
              label: label,
              longitude: lon.toDouble(),
              latitude: lat.toDouble(),
            ),
      ];
    }
    throw const FormatException('GeoJSON without features');
  }
}

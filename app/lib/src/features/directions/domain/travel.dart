/// Temps de trajet : les modes, les réglages du domicile, et les règles
/// pures qui transforment une réponse du service d'itinéraire en durée
/// affichable.
///
/// Choix non évidents :
/// - deux modes seulement, voiture et marche : ceux que l'itinéraire de
///   l'IGN calcule. Ses durées ignorent le trafic et l'heure : une même
///   paire (départ, arrivée) a une seule durée, quel que soit le rdv ;
/// - le domicile part arrondi au millième de degré (~100 m,
///   [roundedOrigin]) : la durée n'en souffre pas, et le service ne reçoit
///   pas l'adresse exacte à chaque calcul ;
/// - le service recale sur le réseau français un point qui en sort (une
///   adresse à Bruxelles devient la frontière près de Givet) sans le dire :
///   [isNear] écarte un point déplacé de plus de [snapTolerance] ;
/// - un lieu de rdv est du texte libre. Le service trouve presque toujours
///   quelque chose, même pour « Chez Paul » ou « Bureau » (une rue, un
///   lieu-dit à l'autre bout de la France) : [mentionsPlace] n'accepte un
///   lieu que si sa commune ou son code postal figure dans le texte. Mieux
///   vaut pas de trajet qu'un trajet absurde.
///
/// Invariant : fonctions pures, sans horloge ni E/S.
library;

import 'dart:math' as math;

import 'package:agora/src/features/directions/domain/address.dart';

enum TravelMode { car, walk }

/// Le mode choisi dans Moi → Trajets ; [auto] marche jusqu'à
/// [autoWalkLimit], conduit au-delà.
enum TravelPreference {
  auto,
  car,
  walk;

  TravelMode? get mode => switch (this) {
    auto => null,
    car => TravelMode.car,
    walk => TravelMode.walk,
  };

  static TravelPreference fromCode(String? code) =>
      values.firstWhere((value) => value.name == code, orElse: () => auto);
}

/// Le mode choisi pour un rdv (ou une série) ; [none] : pas de trajet.
enum TravelChoice {
  car,
  walk,
  none;

  TravelMode? get mode => switch (this) {
    car => TravelMode.car,
    walk => TravelMode.walk,
    none => null,
  };

  static TravelChoice? fromCode(String? code) {
    for (final value in values) {
      if (value.name == code) return value;
    }
    return null;
  }
}

/// Les réglages de trajet d'une personne, qui n'existent qu'avec un
/// domicile.
final class TravelSettings {
  const TravelSettings({
    required this.home,
    this.preference = TravelPreference.auto,
    this.showInAgenda = true,
  });

  final Address home;
  final TravelPreference preference;

  /// Dessiner le trajet avant chaque rdv dans l'agenda.
  final bool showInAgenda;

  @override
  bool operator ==(Object other) =>
      other is TravelSettings &&
      other.home == home &&
      other.preference == preference &&
      other.showInAgenda == showInAgenda;

  @override
  int get hashCode => Object.hash(home, preference, showInAgenda);
}

/// Le trajet retenu pour un rdv.
final class TravelEstimate {
  const TravelEstimate(this.mode, this.duration);

  final TravelMode mode;
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is TravelEstimate &&
      other.mode == mode &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(mode, duration);
}

/// Un point WGS 84, en degrés.
typedef GeoPoint = ({double longitude, double latitude});

/// Jusqu'à cette durée de marche, le mode automatique choisit la marche.
const autoWalkLimit = Duration(minutes: 15);

/// Distance au-delà de laquelle un point recalé n'est plus celui demandé.
const snapTolerance = 500.0;

/// Le point de [address].
GeoPoint pointOf(Address address) =>
    (longitude: address.longitude, latitude: address.latitude);

/// Le domicile tel qu'il part vers le service d'itinéraire : arrondi au
/// millième de degré.
GeoPoint roundedOrigin(Address home) => (
  longitude: _thousandth(home.longitude),
  latitude: _thousandth(home.latitude),
);

double _thousandth(double degrees) => (degrees * 1000).round() / 1000;

/// Le mode automatique, d'après la durée à pied (`null` : pas de chemin).
TravelMode autoMode(Duration? walk) =>
    walk != null && walk <= autoWalkLimit ? TravelMode.walk : TravelMode.car;

/// L'heure de départ pour arriver à [start], à la minute (vers le plus tôt).
DateTime departureFor(DateTime start, Duration travel) =>
    start.subtract(travel).copyWith(second: 0, millisecond: 0, microsecond: 0);

/// Vrai si [returned] est à moins de [snapTolerance] mètres de [asked].
bool isNear(GeoPoint asked, GeoPoint returned) =>
    _metersBetween(asked, returned) <= snapTolerance;

double _metersBetween(GeoPoint a, GeoPoint b) {
  const earthRadius = 6371000.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final dLat = radians(b.latitude - a.latitude);
  final dLon = radians(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(radians(a.latitude)) *
          math.cos(radians(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

/// Vrai si [text] nomme l'une des [cities] ou l'un des [postcodes], en mots
/// entiers, sans tenir compte des accents, de la casse ni des traits
/// d'union.
bool mentionsPlace(
  String text, {
  required Iterable<String> cities,
  required Iterable<String> postcodes,
}) {
  final words = ' ${_fold(text)} ';
  return [...cities, ...postcodes].any((name) {
    final folded = _fold(name);
    return folded.isNotEmpty && words.contains(' $folded ');
  });
}

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ÿ': 'y', 'ç': 'c', 'œ': 'oe', 'æ': 'ae',
};

final _separators = RegExp(r'[^a-z0-9]+');

/// Minuscules sans accents, mots séparés par une seule espace.
String _fold(String text) {
  final lower = text.toLowerCase();
  final plain = StringBuffer();
  for (final char in lower.split('')) {
    plain.write(_accents[char] ?? char);
  }
  return plain.toString().replaceAll(_separators, ' ').trim();
}

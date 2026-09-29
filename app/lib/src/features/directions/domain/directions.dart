/// « Y aller » : le lien qui ouvre l'app d'itinéraire du téléphone sur le
/// lieu d'un rdv, en transports en commun.
///
/// Choix non évidents :
/// - Agora ne calcule aucun trajet et n'appelle aucun service : elle passe
///   la main à l'app choisie par la personne. Rien n'est enregistré, aucun
///   sous-traitant n'entre en jeu — le lieu part vers cette app parce que
///   la personne l'a demandé ;
/// - sans adresse de départ, aucune n'est envoyée : l'app d'itinéraire part
///   alors de la position du téléphone, qu'Agora n'a pas besoin de connaître
///   (pas de permission de localisation) ;
/// - Google Maps n'accepte pas d'heure d'arrivée dans un lien (API « api=1 »
///   documentée) ; Citymapper, si (`arrival_time`). L'écran affiche l'heure
///   visée pour qu'on la reporte dans Google Maps ;
/// - « Autre app » passe par un lien `geo:` : Android propose alors toutes
///   les apps de cartes installées, avec le lieu seul.
///
/// Invariant : fonctions pures, sans horloge ni E/S.
library;

enum DirectionsApp { googleMaps, citymapper, other }

/// Le trajet demandé.
final class Trip {
  const Trip({required this.destination, this.origin, this.arriveBy});

  /// Le lieu du rdv, tel que saisi (texte libre).
  final String destination;

  /// Adresse de départ saisie pour ce calcul ; vide ou nulle : position du
  /// téléphone.
  final String? origin;

  /// Heure d'arrivée visée, ou nulle.
  final DateTime? arriveBy;
}

/// Le lien qui ouvre [app] sur [trip].
Uri directionsLink(DirectionsApp app, Trip trip) {
  final origin = trip.origin?.trim() ?? '';
  final destination = trip.destination.trim();
  return switch (app) {
    DirectionsApp.googleMaps => Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      if (origin.isNotEmpty) 'origin': origin,
      'destination': destination,
      'travelmode': 'transit',
    }),
    DirectionsApp.citymapper => Uri.https('citymapper.com', '/directions', {
      if (origin.isNotEmpty) 'startaddress': origin,
      'endaddress': destination,
      'endname': destination,
      if (trip.arriveBy case final at?)
        'arrival_time': at.toUtc().toIso8601String(),
    }),
    // Uri(queryParameters:) coderait les espaces en « + », que les apps de
    // cartes lisent littéralement : %20 est compris partout.
    DirectionsApp.other => Uri.parse(
      'geo:0,0?q=${Uri.encodeComponent(destination)}',
    ),
  };
}

/// L'heure d'arrivée à viser : le début d'un rdv à venir. Aucune pour une
/// journée entière (pas d'heure) ni pour un rdv déjà commencé.
DateTime? wantedArrival({
  required DateTime start,
  required bool isAllDay,
  required DateTime now,
}) {
  if (isAllDay || !start.isAfter(now)) return null;
  return start;
}

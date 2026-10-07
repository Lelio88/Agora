/// Clés du bouton « Y aller », de sa feuille, de l'écran « Trajets » et des
/// temps de trajet d'une fiche, pour les tests.
library;

import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:flutter/widgets.dart';

abstract final class DirectionsKeys {
  static const goThere = ValueKey('directions.goThere');
  static const arriveBy = ValueKey('directions.arriveBy');
  static const origin = ValueKey('directions.origin');
  static const fromMyPosition = ValueKey('directions.fromMyPosition');
  static const citymapper = ValueKey('directions.citymapper');
  static const googleMaps = ValueKey('directions.googleMaps');
  static const otherApp = ValueKey('directions.otherApp');

  static const travelScreen = ValueKey('directions.travelScreen');
  static const home = ValueKey('directions.home');
  static const clearHome = ValueKey('directions.clearHome');
  static const homeField = ValueKey('directions.homeField');
  static const searchError = ValueKey('directions.searchError');
  static ValueKey<String> suggestion(int index) =>
      ValueKey('directions.suggestion.$index');
  static ValueKey<String> preference(TravelPreference preference) =>
      ValueKey('directions.preference.${preference.name}');
  static const showInAgenda = ValueKey('directions.showInAgenda');

  static const setHomeHint = ValueKey('directions.setHomeHint');
  static const placeUnknown = ValueKey('directions.placeUnknown');
  static const departure = ValueKey('directions.departure');
  static ValueKey<String> choice(TravelChoice choice) =>
      ValueKey('directions.choice.${choice.name}');
  static ValueKey<String> strip(String instanceKey) =>
      ValueKey('directions.strip.$instanceKey');
}

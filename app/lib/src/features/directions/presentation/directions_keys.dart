/// Clés du bouton « Y aller », de sa feuille et de l'écran « Trajets », pour
/// les tests.
library;

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
}

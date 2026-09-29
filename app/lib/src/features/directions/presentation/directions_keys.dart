/// Clés du bouton « Y aller » et de sa feuille, pour les tests.
library;

import 'package:flutter/widgets.dart';

abstract final class DirectionsKeys {
  static const goThere = ValueKey('directions.goThere');
  static const arriveBy = ValueKey('directions.arriveBy');
  static const origin = ValueKey('directions.origin');
  static const citymapper = ValueKey('directions.citymapper');
  static const googleMaps = ValueKey('directions.googleMaps');
  static const otherApp = ValueKey('directions.otherApp');
}

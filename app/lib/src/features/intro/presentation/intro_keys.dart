/// Clés de l'écran d'introduction, pour que les tests le visent sans dépendre
/// de ce qu'il dessine.
library;

import 'package:flutter/widgets.dart';

abstract final class IntroKeys {
  static const screen = ValueKey('intro.screen');
}

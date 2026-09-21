/// Clés de l'écran de profil, pour les tests.
library;

import 'package:flutter/widgets.dart';

abstract final class ProfileKeys {
  static const screen = ValueKey('profile.screen');
  static const displayName = ValueKey('profile.displayName');
  static const language = ValueKey('profile.language');
  static const useDeviceTimezone = ValueKey('profile.useDeviceTimezone');
  static const save = ValueKey('profile.save');
  static const signOut = ValueKey('profile.signOut');
}

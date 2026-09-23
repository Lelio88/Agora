/// Clés de l'écran de profil, pour les tests.
library;

import 'package:flutter/widgets.dart';

abstract final class ProfileKeys {
  static const screen = ValueKey('profile.screen');
  static const displayName = ValueKey('profile.displayName');
  static const language = ValueKey('profile.language');
  static const useDeviceTimezone = ValueKey('profile.useDeviceTimezone');
  static const save = ValueKey('profile.save');
  static const legalPrivacy = ValueKey('profile.legalPrivacy');
  static const legalNotice = ValueKey('profile.legalNotice');
  static const legalTerms = ValueKey('profile.legalTerms');
  static const signOut = ValueKey('profile.signOut');
  static const deleteAccount = ValueKey('profile.deleteAccount');
  static const confirmDelete = ValueKey('profile.confirmDelete');
  static const cancelDelete = ValueKey('profile.cancelDelete');
}

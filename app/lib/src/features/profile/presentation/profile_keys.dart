/// Clés de l'écran de profil, pour les tests.
library;

import 'package:agora/src/features/profile/domain/profile.dart';
import 'package:flutter/widgets.dart';

abstract final class ProfileKeys {
  static const screen = ValueKey('profile.screen');
  static const displayName = ValueKey('profile.displayName');
  static const editName = ValueKey('profile.editName');
  static const language = ValueKey('profile.language');
  static ValueKey<String> languageOption(AppLanguage language) =>
      ValueKey('profile.language.${language.name}');
  static const timezone = ValueKey('profile.timezone');
  static const calendars = ValueKey('profile.calendars');
  static const travel = ValueKey('profile.travel');
  static const useDeviceTimezone = ValueKey('profile.useDeviceTimezone');
  static const save = ValueKey('profile.save');
  static const legalPrivacy = ValueKey('profile.legalPrivacy');
  static const legalNotice = ValueKey('profile.legalNotice');
  static const legalTerms = ValueKey('profile.legalTerms');
  static const assistant = ValueKey('profile.assistant');
  static const signOut = ValueKey('profile.signOut');
  static const deleteAccount = ValueKey('profile.deleteAccount');
  static const alsoDeleteEvents = ValueKey('profile.alsoDeleteEvents');
  static const confirmDelete = ValueKey('profile.confirmDelete');
  static const cancelDelete = ValueKey('profile.cancelDelete');
}

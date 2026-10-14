/// Clés des écrans de liens de profil, pour les tests.
library;

import 'package:agora/src/features/profile_link/domain/profile_link.dart';
import 'package:flutter/widgets.dart';

abstract final class ProfileLinkKeys {
  // Mes liens.
  static const screen = ValueKey('profileLinks.screen');
  static const newLink = ValueKey('profileLinks.new');
  static ValueKey<String> tile(String code) =>
      ValueKey('profileLinks.tile.$code');

  // Création.
  static const labelField = ValueKey('profileLinks.new.label');
  static ValueKey<String> levelOption(ProfileLinkLevel level) =>
      ValueKey('profileLinks.new.level.${level.name}');
  static const create = ValueKey('profileLinks.new.create');

  // Fenêtre d'un lien.
  static const qr = ValueKey('profileLinks.sheet.qr');
  static const url = ValueKey('profileLinks.sheet.url');
  static const share = ValueKey('profileLinks.sheet.share');
  static const copyLink = ValueKey('profileLinks.sheet.copy');
  static const revoke = ValueKey('profileLinks.sheet.revoke');

  // Ouvrir le lien d'un autre.
  static const openScreen = ValueKey('profileLinks.open');
  static const openConfirm = ValueKey('profileLinks.open.confirm');
}

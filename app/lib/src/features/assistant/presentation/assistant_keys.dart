/// Clés des écrans des assistants IA, pour les tests.
library;

import 'package:flutter/widgets.dart';

abstract final class AssistantKeys {
  // Écran « Assistant IA » (profil).
  static const screen = ValueKey('assistant.screen');
  static const connect = ValueKey('assistant.connect');
  static const address = ValueKey('assistant.address');
  static const copyAddress = ValueKey('assistant.address.copy');
  static const copyCommand = ValueKey('assistant.command.copy');
  static const guide = ValueKey('assistant.guide');
  static const noGrant = ValueKey('assistant.grants.none');
  static const unavailable = ValueKey('assistant.grants.unavailable');
  static ValueKey<String> grant(String clientId) =>
      ValueKey('assistant.grant.$clientId');
  static ValueKey<String> revoke(String clientId) =>
      ValueKey('assistant.grant.$clientId.revoke');
  static const confirmRevoke = ValueKey('assistant.grant.revoke.confirm');
}

abstract final class ConsentKeys {
  static const screen = ValueKey('consent.screen');
  static const approve = ValueKey('consent.approve');
  static const deny = ValueKey('consent.deny');
  static const notMe = ValueKey('consent.notMe');
  static const refused = ValueKey('consent.refused');
  static const handedOver = ValueKey('consent.handedOver');
  static const failed = ValueKey('consent.failed');
  static const home = ValueKey('consent.home');
}

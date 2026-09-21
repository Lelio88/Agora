/// Accès au fuseau horaire de l'appareil, derrière une interface pour que les
/// tests fournissent un fuseau fixe.
///
/// Sert à l'inscription (le profil naît dans le fuseau de l'appareil) et au
/// bouton « Utiliser celui de cet appareil » du profil. L'implémentation est
/// branchée à la composition root.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fuseau retenu quand l'appareil ne sait pas répondre.
const fallbackTimezone = 'Europe/Paris';

abstract interface class DeviceTimezone {
  /// Identifiant IANA du fuseau de l'appareil (ex. `Europe/Paris`).
  Future<String> current();
}

final deviceTimezoneProvider = Provider<DeviceTimezone>(
  (ref) => throw UnimplementedError(
    'deviceTimezoneProvider must be overridden at the composition root.',
  ),
);

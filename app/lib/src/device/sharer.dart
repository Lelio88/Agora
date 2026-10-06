/// Partage d'un texte par la feuille de partage du téléphone (WhatsApp,
/// SMS, e-mail…), derrière une interface pour que les tests constatent ce
/// qui aurait été partagé.
///
/// Choix non évident : [isAvailable] est faux sur le web. Sans l'API de
/// partage du navigateur, share_plus y retombe sur un lien e-mail ; là, on
/// garde « Copier », qui fait toujours ce qu'il annonce.
///
/// L'implémentation est branchée à la composition root.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class Sharer {
  /// Vrai si l'appareil a une vraie feuille de partage.
  bool get isAvailable;

  /// Ouvre la feuille de partage sur [text] ; [subject] sert aux e-mails.
  Future<void> share(String text, {String? subject});
}

final sharerProvider = Provider<Sharer>(
  (ref) => throw UnimplementedError(
    'sharerProvider must be overridden at the composition root.',
  ),
);

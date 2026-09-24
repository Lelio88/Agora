/// Le jingle de l'écran d'introduction, derrière une interface pour que les
/// tests constatent qu'il est parti, sans plugin audio ni carte son.
///
/// Choix non évident : l'app ne règle ni le volume ni le canal. Le jingle
/// passe par le canal « média » du téléphone, donc il se tait quand l'appareil
/// est en silencieux et suit le volume que la personne a choisi. Forcer un
/// volume, ou passer par le canal des alarmes pour « être sûr qu'on l'entend »,
/// est précisément ce qui fait désinstaller une application.
///
/// Invariant : aucune de ces méthodes ne lève. Un son qui ne part pas ne doit
/// jamais retenir quelqu'un devant un écran de lancement.
///
/// L'implémentation est branchée à la composition root.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class IntroSound {
  /// Joue le jingle depuis le début. Sans effet si l'appareil n'a pas de quoi.
  Future<void> play();

  /// Libère le lecteur. Appelée quand l'intro quitte l'arbre.
  Future<void> dispose();
}

final introSoundProvider = Provider<IntroSound>(
  (ref) => throw UnimplementedError(
    'introSoundProvider must be overridden at the composition root.',
  ),
);

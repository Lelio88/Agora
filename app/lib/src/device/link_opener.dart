/// Ouverture d'un lien hors de l'app (pages légales), derrière une interface
/// pour que les tests constatent ce qui aurait été ouvert, sans navigateur.
///
/// Choix non évident : l'app n'affiche pas ces pages elle-même. Elles sont
/// servies par la version web, à une adresse stable que la fiche Play Store
/// donne aussi ; les afficher en double dans l'app ferait deux textes à tenir
/// à jour, et un seul serait relu.
///
/// Invariant : une ouverture qui échoue ne fait pas tomber l'app — elle rend
/// `false`, et l'écran le dit.
///
/// L'implémentation est branchée à la composition root.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class LinkOpener {
  /// Ouvre [url] hors de l'app. Rend `false` si l'appareil n'a rien pour le
  /// faire.
  Future<bool> open(Uri url);
}

final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => throw UnimplementedError(
    'linkOpenerProvider must be overridden at the composition root.',
  ),
);

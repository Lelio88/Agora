/// Un lien de rdv venu d'une autre app (`#/event?…`, `domain/event_link.dart`)
/// ouvert alors que personne n'était connecté : le routeur le retient le
/// temps de la connexion, puis y ramène, comme une invitation ou un lien de
/// jumelage. L'écran du lien le consomme.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

final class PendingEventLink {
  String? location;
}

final pendingEventLinkProvider = Provider<PendingEventLink>(
  (ref) => PendingEventLink(),
);

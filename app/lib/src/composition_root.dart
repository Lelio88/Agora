/// Composition root : le **seul** fichier (avec `main.dart`) autorisé à
/// importer les couches `data/`.
///
/// Chaque feature déclare dans son `application/` un `*RepositoryProvider`
/// qui lève `UnimplementedError`, et l'implémentation concrète est branchée
/// ici. Le test de démarrage monte l'app sous [prodOverrides] : un override
/// oublié le fait échouer.
///
/// Après toute modification de cette liste, faire un hot **restart** (`R`) :
/// un hot reload ne réévalue pas les variables de haut niveau.
library;

import 'package:flutter_riverpod/misc.dart';

final List<Override> prodOverrides = [];

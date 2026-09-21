/// Routeur d'Agora (GoRouter) : la navigation se fait **par nom de route**
/// (`context.goNamed(AppRoute.home.name)`), jamais par chemin écrit en dur.
///
/// La redirection vers la connexion arrivera avec la feature `auth`, via
/// `refreshListenable` branché sur le flux de session. Un contrôle de session
/// dans un widget laisserait voir le contenu protégé une fraction de seconde.
library;

import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum AppRoute { home }

final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.home.name,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

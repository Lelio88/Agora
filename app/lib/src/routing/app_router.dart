/// Routeur d'Agora (GoRouter) : la navigation se fait **par nom de route**
/// (`context.goNamed(AppRoute.home.name)`), jamais par chemin écrit en dur.
///
/// La redirection selon la session vit dans `redirect`, réévaluée à chaque
/// connexion ou déconnexion via `refreshListenable`. Un contrôle de session
/// dans un widget laisserait voir le contenu protégé une fraction de seconde.
/// La règle elle-même est dans `auth_redirect.dart`.
library;

import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/presentation/forgot_password_screen.dart';
import 'package:agora/src/features/auth/presentation/reset_password_screen.dart';
import 'package:agora/src/features/auth/presentation/sign_in_screen.dart';
import 'package:agora/src/features/auth/presentation/sign_up_screen.dart';
import 'package:agora/src/features/auth/presentation/verify_email_screen.dart';
import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:agora/src/features/profile/presentation/profile_screen.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:agora/src/routing/auth_redirect.dart';
import 'package:agora/src/routing/stream_listenable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = StreamListenable(auth.watchCurrentUser());
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      isSignedIn: auth.currentUser != null,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.home.name,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: AppRoute.profile.name,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        name: AppRoute.signIn.name,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        name: AppRoute.signUp.name,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        name: AppRoute.verifyEmail.name,
        redirect: _requireEmail,
        builder: (context, state) =>
            VerifyEmailScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/forgot-password',
        name: AppRoute.forgotPassword.name,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: AppRoute.resetPassword.name,
        redirect: _requireEmail,
        builder: (context, state) => ResetPasswordScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Les écrans de code n'ont de sens qu'avec l'adresse à laquelle le code est
/// parti : sans elle (lien tronqué, favori), retour à la connexion.
String? _requireEmail(BuildContext context, GoRouterState state) =>
    (state.uri.queryParameters['email'] ?? '').trim().isEmpty
    ? '/sign-in'
    : null;

/// Routeur d'Agora (GoRouter) : la navigation se fait **par nom de route**
/// (`context.goNamed(AppRoute.home.name)`), jamais par chemin écrit en dur.
///
/// La redirection selon la session vit dans `redirect`, réévaluée à chaque
/// connexion ou déconnexion via `refreshListenable`. Un contrôle de session
/// dans un widget laisserait voir le contenu protégé une fraction de seconde.
/// La règle elle-même est dans `auth_redirect.dart`.
///
/// Un groupe et « Rejoindre » sont des sous-routes de l'accueil : ouverts
/// par un lien, le retour ramène à l'accueil. Un rdv de groupe (fiche,
/// proposition) est une sous-route de son groupe ; ses écrans viennent de la
/// feature agenda, que l'écran du groupe ouvre par leur seul nom de route. Un lien d'invitation ouvert
/// déconnecté est retenu ([PendingInvite]) jusqu'à la connexion.
library;

import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/presentation/forgot_password_screen.dart';
import 'package:agora/src/features/auth/presentation/reset_password_screen.dart';
import 'package:agora/src/features/auth/presentation/sign_in_screen.dart';
import 'package:agora/src/features/auth/presentation/sign_up_screen.dart';
import 'package:agora/src/features/auth/presentation/verify_email_screen.dart';
import 'package:agora/src/features/calendar/presentation/group_event_editor_page.dart';
import 'package:agora/src/features/calendar/presentation/group_event_screen.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/presentation/group_screen.dart';
import 'package:agora/src/features/groups/presentation/join_group_screen.dart';
import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:agora/src/features/profile/presentation/profile_screen.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:agora/src/routing/auth_redirect.dart';
import 'package:agora/src/routing/stream_listenable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final pendingInvite = ref.watch(pendingInviteProvider);
  final refresh = StreamListenable(auth.watchCurrentUser());
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isSignedIn = auth.currentUser != null;
      final location = state.matchedLocation;
      final invite = inviteCodeInLocation(location);
      if (!isSignedIn && invite != null) pendingInvite.code = invite;
      return authRedirect(
        isSignedIn: isSignedIn,
        location: location,
        pendingInvite: pendingInvite.code,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.home.name,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'groups/:groupId',
            name: AppRoute.group.name,
            builder: (context, state) =>
                GroupScreen(groupId: state.pathParameters['groupId']!),
            routes: [
              // Avant « events/:eventId », qui prendrait « new » pour un id.
              GoRoute(
                path: 'events/new',
                name: AppRoute.groupEventNew.name,
                pageBuilder: (context, state) => MaterialPage<void>(
                  key: state.pageKey,
                  fullscreenDialog: true,
                  child: GroupEventEditorPage(
                    groupId: state.pathParameters['groupId']!,
                    initialStart: _instant(state.uri.queryParameters['start']),
                  ),
                ),
              ),
              GoRoute(
                path: 'events/:eventId',
                name: AppRoute.groupEvent.name,
                builder: (context, state) => GroupEventScreen(
                  groupId: state.pathParameters['groupId']!,
                  eventId: state.pathParameters['eventId']!,
                  start: _instant(state.uri.queryParameters['start']),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'join',
            name: AppRoute.joinByCode.name,
            builder: (context, state) => const JoinGroupScreen(),
          ),
          GoRoute(
            path: 'join/:code',
            name: AppRoute.join.name,
            builder: (context, state) =>
                JoinGroupScreen(code: state.pathParameters['code']),
          ),
        ],
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

/// Instant passé en paramètre d'URL (ISO 8601), ou `null` s'il est absent
/// ou illisible.
DateTime? _instant(String? value) =>
    value == null ? null : DateTime.tryParse(value)?.toUtc();

/// Les écrans de code n'ont de sens qu'avec l'adresse à laquelle le code est
/// parti : sans elle (lien tronqué, favori), retour à la connexion.
String? _requireEmail(BuildContext context, GoRouterState state) =>
    (state.uri.queryParameters['email'] ?? '').trim().isEmpty
    ? '/sign-in'
    : null;

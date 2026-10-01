/// [AuthRepository] adossé à GoTrue (Supabase Auth).
///
/// Choix non évidents :
/// - l'inscription répond pareil, que l'adresse ait déjà un compte ou non
///   ([blindSignUp]) : sinon le formulaire dirait à qui veut quelles adresses
///   sont inscrites. L'écran du code oriente le titulaire vers la connexion
///   et « Mot de passe oublié » ;
/// - [resetPassword] vérifie **toujours** le code, même si une session est
///   ouverte : sinon une session ordinaire (poste partagé, session volée)
///   changerait le mot de passe sans prouver l'accès à la boîte mail. Si
///   l'enregistrement échoue après la vérification, le code est consommé :
///   il faut en redemander un.
///
/// - [deleteAccount] passe par la RPC `delete_my_account` : le Supabase
///   auto-hébergé n'a pas d'edge runtime, et la transmission des groupes doit
///   se faire dans la même transaction que l'effacement.
///
/// Invariant : aucune exception de GoTrue ne sort d'ici sans être traduite.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/data/auth_error_translator.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/domain/auth_repository.dart';
import 'package:agora/src/features/auth/domain/left_behind_event.dart';
import 'package:agora/src/features/auth/domain/social_provider.dart';
import 'package:agora/src/supabase/oauth_callback.dart';
import 'package:agora/src/supabase/postgrest_errors.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> watchCurrentUser() =>
      _auth.onAuthStateChange.map((state) => _toAppUser(state.session?.user));

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
    required String timezone,
    String? captchaToken,
  }) => _guard(
    () => blindSignUp(
      () => _auth.signUp(
        email: email.trim(),
        password: password,
        captchaToken: captchaToken,
        data: {
          'display_name': displayName.trim(),
          'locale': locale,
          'timezone': timezone,
        },
      ),
    ),
  );

  @override
  Future<bool> signInWith(SocialProvider provider) => _guard(
    () => _auth.signInWithOAuth(switch (provider) {
      SocialProvider.google => OAuthProvider.google,
      SocialProvider.discord => OAuthProvider.discord,
    }, redirectTo: oauthRedirect()),
  );

  @override
  Future<void> verifySignUpCode({
    required String email,
    required String code,
  }) => _guard(
    () => _auth.verifyOTP(
      type: OtpType.signup,
      email: email.trim(),
      token: code.trim(),
    ),
  );

  @override
  Future<void> resendSignUpCode({
    required String email,
    String? captchaToken,
  }) => _guard(
    () => _auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      captchaToken: captchaToken,
    ),
  );

  @override
  Future<void> signIn({
    required String email,
    required String password,
    String? captchaToken,
  }) => _guard(
    () => _auth.signInWithPassword(
      email: email.trim(),
      password: password,
      captchaToken: captchaToken,
    ),
  );

  @override
  Future<void> requestPasswordReset({
    required String email,
    String? captchaToken,
  }) => _guard(
    () => _auth.resetPasswordForEmail(email.trim(), captchaToken: captchaToken),
  );

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _guard(() async {
    await _auth.verifyOTP(
      type: OtpType.recovery,
      email: email.trim(),
      token: code.trim(),
    );
    await _auth.updateUser(UserAttributes(password: newPassword));
  });

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<List<LeftBehindEvent>> proposedGroupEvents() => guardPostgrest(
    () async {
      final rows = await _client.rpc<List<dynamic>>('my_proposed_group_events');
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          LeftBehindEvent(
            id: row['event_id'] as String,
            title: row['title'] as String,
            startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
            groupName: row['group_name'] as String,
          ),
      ];
    },
  );

  @override
  Future<int> deleteProposedGroupEvents() =>
      guardPostgrest(() => _client.rpc<int>('delete_my_proposed_group_events'));

  @override
  Future<void> deleteAccount() => _guard(() async {
    await _client.rpc<void>('delete_my_account');
    try {
      await _auth.signOut();
    } on AuthException {
      // Rien à signaler : GoTrue retire la session locale AVANT d'appeler le
      // serveur, et la révocation distante qui échouerait vise une session
      // que la suppression du compte a déjà effacée. Remonter cette erreur
      // annoncerait un échec alors que le compte n'existe plus.
    }
  });

  static AppUser? _toAppUser(User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email);

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on Exception catch (error) {
      throw translateAuthError(error);
    }
  }
}

/// Inscription qui répond pareil, que l'adresse ait déjà un compte ou non.
///
/// Confirmation active, GoTrue répond à un doublon confirmé par un utilisateur
/// factice (sans identité, sans session) et n'envoie rien ; un doublon jamais
/// confirmé reçoit de nouveau son code. Les deux se lisent ici comme un compte
/// neuf, et l'écran du code dit au titulaire d'un compte où aller. Un serveur
/// qui nomme le doublon (`user_already_exists`, quand la confirmation est
/// coupée) reçoit la même réponse. **Ne jamais réintroduire un contrôle
/// `identities.isEmpty`** qui ferait du doublon une erreur.
@visibleForTesting
Future<void> blindSignUp(Future<AuthResponse> Function() signUp) async {
  try {
    await signUp();
  } on AuthException catch (e) {
    if (e.code == 'user_already_exists') return;
    rethrow;
  }
}

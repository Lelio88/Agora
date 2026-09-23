/// [AuthRepository] adossé à GoTrue (Supabase Auth).
///
/// Choix non évidents :
/// - une inscription avec une adresse déjà confirmée peut réussir en
///   apparence : GoTrue renvoie alors un utilisateur sans identité, pour ne
///   pas révéler l'adresse. On le détecte et on lève
///   [EmailAlreadyRegisteredException], sinon l'écran attendrait un code qui
///   ne viendra jamais ;
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
import 'package:agora/src/supabase/postgrest_errors.dart';
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
  }) => _guard(() async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': displayName.trim(),
        'locale': locale,
        'timezone': timezone,
      },
    );
    if (response.user?.identities?.isEmpty ?? false) {
      throw const EmailAlreadyRegisteredException();
    }
  });

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
  Future<void> resendSignUpCode({required String email}) =>
      _guard(() => _auth.resend(type: OtpType.signup, email: email.trim()));

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithPassword(email: email.trim(), password: password),
      );

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _guard(() => _auth.resetPasswordForEmail(email.trim()));

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

  static Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on AppException {
      rethrow;
    } on Exception catch (error) {
      throw translateAuthError(error);
    }
  }
}

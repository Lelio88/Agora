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
/// Invariant : aucune exception de GoTrue ne sort d'ici sans être traduite.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/data/auth_error_translator.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

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

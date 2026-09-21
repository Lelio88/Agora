import 'dart:async';

import 'package:agora/src/device/device_timezone.dart';
import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/domain/auth_repository.dart';
import 'package:agora/src/features/profile/domain/profile.dart';
import 'package:agora/src/features/profile/domain/profile_repository.dart';

/// Faux dépôt d'authentification en mémoire. [nextError] est levée par le
/// prochain appel, puis oubliée ; [calls] garde la trace des appels.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? signedInAs}) : _user = signedInAs;

  /// Seul code accepté par [verifySignUpCode] et [resetPassword].
  static const validCode = '123456';
  static const userId = 'user-1';

  final _changes = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  AppException? nextError;

  /// Tant qu'il n'est pas complété, chaque appel reste « en vol » : permet
  /// de tester l'écran pendant une requête.
  Completer<void>? gate;
  final calls = <String>[];
  Map<String, String>? lastSignUp;
  String? lastNewPassword;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchCurrentUser() async* {
    yield _user;
    yield* _changes.stream;
  }

  void _emit(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  Future<void> _record(String call) async {
    calls.add(call);
    await gate?.future;
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
    required String timezone,
  }) async {
    await _record('signUp');
    lastSignUp = {
      'email': email,
      'displayName': displayName,
      'locale': locale,
      'timezone': timezone,
    };
  }

  @override
  Future<void> verifySignUpCode({
    required String email,
    required String code,
  }) async {
    await _record('verifySignUpCode');
    if (code != validCode) throw const InvalidCodeException();
    _emit(AppUser(id: userId, email: email));
  }

  @override
  Future<void> resendSignUpCode({required String email}) =>
      _record('resendSignUpCode');

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _record('signIn');
    _emit(AppUser(id: userId, email: email));
  }

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _record('requestPasswordReset');

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _record('resetPassword');
    if (code != validCode) throw const InvalidCodeException();
    lastNewPassword = newPassword;
    _emit(AppUser(id: userId, email: email));
  }

  /// Comme GoTrue : la session locale disparaît AVANT l'appel réseau de
  /// révocation, qui peut ensuite échouer ([nextError]).
  @override
  Future<void> signOut() async {
    _emit(null);
    await _record('signOut');
  }

  @override
  Future<void> deleteAccount() async {
    await _record('deleteAccount');
    _emit(null);
  }

  Future<void> dispose() => _changes.close();
}

/// Faux dépôt de profils ; un profil absent est créé à la première lecture,
/// sauf pour les comptes de [deletedUserIds], dont le profil n'existe plus.
class FakeProfileRepository implements ProfileRepository {
  final profiles = <String, Profile>{};
  final deletedUserIds = <String>{};
  AppException? nextError;

  @override
  Future<Profile?> fetchProfile(String userId) async =>
      deletedUserIds.contains(userId)
      ? null
      : profiles.putIfAbsent(
          userId,
          () => Profile(
            id: userId,
            displayName: 'Zoé',
            timezone: 'Europe/Paris',
            language: AppLanguage.fr,
          ),
        );

  @override
  Future<void> updateProfile(Profile profile) async {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    profiles[profile.id] = profile;
  }
}

class FakeDeviceTimezone implements DeviceTimezone {
  const FakeDeviceTimezone(this.timezone);

  final String timezone;

  @override
  Future<String> current() async => timezone;
}

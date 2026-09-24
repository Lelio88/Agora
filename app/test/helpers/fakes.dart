import 'dart:async';

import 'package:agora/src/device/device_timezone.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:flutter/material.dart';
import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/domain/left_behind_event.dart';
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

  /// Jetons « je ne suis pas un robot » reçus, dans l'ordre des appels.
  final captchaTokens = <String?>[];

  /// Rdv proposés à des groupes, qui resteraient après la suppression.
  var leftBehind = <LeftBehindEvent>[];

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

  /// Fait arriver [user] comme si une session venait de s'ouvrir, sans
  /// passer par le formulaire (autre compte que [userId]).
  Future<void> signInAs(AppUser user) async => _emit(user);

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
    String? captchaToken,
  }) async {
    captchaTokens.add(captchaToken);
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
  Future<void> resendSignUpCode({required String email, String? captchaToken}) {
    captchaTokens.add(captchaToken);
    return _record('resendSignUpCode');
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    captchaTokens.add(captchaToken);
    await _record('signIn');
    _emit(AppUser(id: userId, email: email));
  }

  @override
  Future<void> requestPasswordReset({
    required String email,
    String? captchaToken,
  }) {
    captchaTokens.add(captchaToken);
    return _record('requestPasswordReset');
  }

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
  Future<List<LeftBehindEvent>> proposedGroupEvents() async {
    calls.add('proposedGroupEvents');
    return leftBehind;
  }

  @override
  Future<int> deleteProposedGroupEvents() async {
    calls.add('deleteProposedGroupEvents');
    final count = leftBehind.length;
    leftBehind = [];
    return count;
  }

  @override
  Future<void> deleteAccount() async {
    await _record('deleteAccount');
    _emit(null);
  }

  /// Ne pas attendre la fermeture : `close()` d'un flux broadcast n'aboutit
  /// qu'une fois tous les abonnés partis, ce qui dépend de l'ordre des
  /// teardowns et bloquerait le test 30 s.
  void dispose() {
    unawaited(_changes.close());
  }
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

/// Retient les liens qu'on a voulu ouvrir, sans navigateur. [succeeds] à
/// faux rejoue l'appareil qui n'a rien pour les ouvrir.
class FakeLinkOpener implements LinkOpener {
  FakeLinkOpener({this.succeeds = true});

  final bool succeeds;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeeds;
  }
}

/// Case « je ne suis pas un robot » de test : un appui rend un jeton, comme
/// le ferait Cloudflare. Aucun navigateur, aucune vue web.
class FakeCaptchaField extends StatelessWidget {
  const FakeCaptchaField({super.key, required this.onToken});

  static const token = 'jeton-de-test';

  final ValueChanged<String?> onToken;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    key: AuthKeys.captcha,
    onPressed: () => onToken(token),
    child: const Text('captcha'),
  );
}

class FakeDeviceTimezone implements DeviceTimezone {
  const FakeDeviceTimezone(this.timezone);

  final String timezone;

  @override
  Future<String> current() async => timezone;
}

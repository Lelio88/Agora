import 'package:agora/src/app.dart';
import 'package:agora/src/device/device_timezone.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/features/profile/presentation/profile_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Pilote l'app entière sous des faux dépôts : les tests se lisent comme le
/// parcours d'un utilisateur, et les sélecteurs vivent ici seulement.
class AgoraRobot {
  AgoraRobot(this.tester);

  final WidgetTester tester;
  late final FakeAuthRepository auth;
  late final FakeProfileRepository profiles;

  /// Monte l'app. [locale] force la langue ; sans elle, la langue suit le
  /// profil (puis celle de l'appareil de test, l'anglais).
  Future<void> pumpApp({
    FakeAuthRepository? auth,
    FakeProfileRepository? profiles,
    Locale? locale = const Locale('fr'),
    String deviceTimezone = 'America/Montreal',
  }) async {
    this.auth = auth ?? FakeAuthRepository();
    this.profiles = profiles ?? FakeProfileRepository();
    addTearDown(this.auth.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(this.auth),
          profileRepositoryProvider.overrideWithValue(this.profiles),
          deviceTimezoneProvider.overrideWithValue(
            FakeDeviceTimezone(deviceTimezone),
          ),
        ],
        child: AgoraApp(locale: locale),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(Key field, String text) async {
    await tester.enterText(find.byKey(field), text);
    await tester.pump();
  }

  Future<void> tap(Key target) async {
    await tester.ensureVisible(find.byKey(target));
    await tester.tap(find.byKey(target));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(String email, String password) async {
    await enter(AuthKeys.email, email);
    await enter(AuthKeys.password, password);
    await tap(AuthKeys.submit);
  }

  Future<void> openProfile() => tap(HomeKeys.profileButton);

  Future<void> selectLanguage(String label) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(ProfileKeys.language),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectText(String text) => expect(find.text(text), findsOneWidget);

  void expectScreen(Key screen) => expect(find.byKey(screen), findsOneWidget);
}

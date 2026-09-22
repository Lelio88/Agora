import 'package:agora/src/app.dart';
import 'package:agora/src/config/web_links.dart';
import 'package:agora/src/device/device_timezone.dart';
import 'package:agora/src/exceptions/async_error_logger.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/features/profile/presentation/profile_keys.dart';
import 'package:agora/src/logging/app_logger.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_calendar_repository.dart';
import 'fake_calendars_repository.dart';
import 'fake_groups_repository.dart';
import 'fakes.dart';
import 'recording_app_logger.dart';

/// Pilote l'app entière sous des faux dépôts : les tests se lisent comme le
/// parcours d'un utilisateur, et les sélecteurs vivent ici seulement.
class AgoraRobot {
  AgoraRobot(this.tester);

  final WidgetTester tester;
  late final FakeAuthRepository auth;
  late final FakeProfileRepository profiles;
  late final FakeCalendarRepository calendar;
  late final FakeCalendarsRepository calendars;
  late final FakeGroupsRepository groups;

  /// Erreurs remontées par les providers, comme en production
  /// (`AsyncErrorLogger`) : un parcours réussi n'en laisse aucune.
  final logger = RecordingAppLogger();

  /// Monte l'app. [locale] force la langue ; sans elle, la langue suit le
  /// profil (puis celle de l'appareil de test, l'anglais).
  Future<void> pumpApp({
    FakeAuthRepository? auth,
    FakeProfileRepository? profiles,
    FakeCalendarRepository? calendar,
    FakeCalendarsRepository? calendars,
    FakeGroupsRepository? groups,
    Uri? webBaseUrl,
    Locale? locale = const Locale('fr'),
    String deviceTimezone = 'America/Montreal',
  }) async {
    this.auth = auth ?? FakeAuthRepository();
    this.profiles = profiles ?? FakeProfileRepository();
    this.calendar = calendar ?? FakeCalendarRepository();
    this.calendars = calendars ?? FakeCalendarsRepository();
    this.groups = groups ?? FakeGroupsRepository();
    addTearDown(this.auth.dispose);
    addTearDown(this.calendar.dispose);
    addTearDown(this.calendars.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        observers: [AsyncErrorLogger()],
        overrides: [
          appLoggerProvider.overrideWithValue(logger),
          authRepositoryProvider.overrideWithValue(this.auth),
          profileRepositoryProvider.overrideWithValue(this.profiles),
          calendarRepositoryProvider.overrideWithValue(this.calendar),
          calendarsRepositoryProvider.overrideWithValue(this.calendars),
          groupsRepositoryProvider.overrideWithValue(this.groups),
          webBaseUrlProvider.overrideWithValue(webBaseUrl),
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
    // Le défilement déclenché par ensureVisible n'est dessiné qu'à l'image
    // suivante : sans cette attente, l'appui vise l'ancienne position.
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(target));
    await settle();
  }

  /// Comme `pumpAndSettle`, mais laisse aussi passer les `await` d'un
  /// gestionnaire (lectures de providers déjà résolus) qui ne planifient
  /// aucune image avant d'ouvrir un écran.
  Future<void> settle() async {
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
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

  /// Ouvre l'éditeur par le bouton « + » de l'agenda.
  Future<void> openNewEvent() => tap(CalendarKeys.newEvent);

  /// Appuie sur la tuile d'un rdv (la première portant ce titre), après
  /// avoir fait défiler la grille horaire jusqu'à elle.
  Future<void> tapEvent(String title) async {
    final tile = find.text(title).first;
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await settle();
  }

  /// Revient à l'écran précédent par la flèche de l'AppBar
  /// (`pageBack` cherche l'infobulle anglaise « Back »).
  Future<void> goBack() async {
    await tester.tap(find.byType(BackButton));
    await settle();
  }

  /// Ouvre l'onglet « Groupes » de l'accueil.
  Future<void> openGroupsTab() => tap(HomeKeys.groupsTab);

  /// Ouvre le groupe [groupId] depuis l'onglet « Groupes ».
  Future<void> openGroup(String groupId) async {
    await openGroupsTab();
    await tap(GroupKeys.groupTile(groupId));
  }

  /// Ouvre [location] comme un lien reçu (le routeur applique ses règles).
  Future<void> openLink(String location) async {
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(location);
    await settle();
  }

  /// Ouvre « Mes agendas » depuis la barre de l'agenda.
  Future<void> openCalendars() => tap(CalendarKeys.manageCalendars);

  /// Choisit l'agenda [calendarId] dans le menu de l'éditeur de rdv.
  Future<void> chooseCalendar(String calendarId) async {
    await tap(CalendarKeys.eventCalendar);
    // Le menu ouvert duplique chaque entrée : la dernière est celle du menu.
    await tester.tap(
      find.byKey(CalendarKeys.eventCalendarOption(calendarId)).last,
    );
    await tester.pumpAndSettle();
  }

  /// Déplace la tuile [title] de [by] comme sur un téléphone (les tests
  /// tournent en Android) : appui long, puis glisser, puis lâcher.
  Future<void> dragEvent(String title, Offset by) async {
    final tile = find.text(title).first;
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    // En plusieurs pas : la cible du dépôt suit le doigt.
    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(by / 4);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await settle();
  }

  void expectText(String text) => expect(find.text(text), findsOneWidget);

  void expectScreen(Key screen) => expect(find.byKey(screen), findsOneWidget);
}

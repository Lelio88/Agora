import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/intro/presentation/intro_keys.dart';
import 'package:agora/src/features/intro/presentation/intro_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/agora_robot.dart';
import '../../../helpers/fakes.dart';

void main() {
  // L'intro recouvre l'app pendant que celle-ci se monte. Ce qui suit vérifie
  // les trois choses qui, si elles cassent, bloquent quelqu'un devant une
  // animation : elle s'efface seule, un appui la saute, et elle ne rejoue pas.
  group('intro', () {
    testWidgets("l'app est déjà montée sous l'intro, puis se découvre", (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      await robot.pumpIntro();

      expect(find.byKey(IntroKeys.screen), findsOneWidget);
      // **L'écran de connexion est là dès le premier frame**, sous l'intro :
      // ses requêtes partent pendant l'animation au lieu de la suivre.
      expect(find.byKey(AuthKeys.signInScreen), findsOneWidget);

      await tester.pump(introFloor);
      await tester.pumpAndSettle();

      expect(find.byKey(IntroKeys.screen), findsNothing);
      expect(find.byKey(AuthKeys.signInScreen), findsOneWidget);
    });

    testWidgets('un appui saute l\'attente', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpIntro();

      await tester.tap(find.byKey(IntroKeys.screen));
      await tester.pumpAndSettle();

      expect(find.byKey(IntroKeys.screen), findsNothing);
    });

    testWidgets('le jingle part une fois, avec l\'animation', (tester) async {
      final robot = AgoraRobot(tester);
      final son = FakeIntroSound();
      await robot.pumpIntro(sound: son);

      expect(son.plays, 1);

      await tester.pump(introFloor);
      await tester.pumpAndSettle();

      expect(son.plays, 1, reason: "l'intro ne se rejoue pas en s'effaçant");
    });

    testWidgets('sans animations, l\'intro ne retient personne', (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      final son = FakeIntroSound();
      // Réglage d'accessibilité « réduire les animations » : une intro qui
      // s'impose quand même est exactement ce que ce réglage interdit.
      await robot.pumpIntro(sound: son, disableAnimations: true);

      expect(find.byKey(IntroKeys.screen), findsNothing);
      expect(son.plays, 0);
    });

    testWidgets("les tests ordinaires n'en voient rien", (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp();

      expect(find.byKey(IntroKeys.screen), findsNothing);
    });
  });
}

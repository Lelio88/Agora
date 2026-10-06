import 'package:agora/src/common_widgets/agenda_view.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kalender/kalender.dart';

const _keys = AgendaToolbarKeys('test');
const _actionKey = ValueKey('test.action');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  group('agendaPeriodLabel', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    final en = lookupAppLocalizations(const Locale('en'));

    String label(
      AgendaView view,
      DateTime start,
      DateTime end,
      AppLocalizations l10n,
    ) => agendaPeriodLabel(view: view, start: start, end: end, l10n: l10n);

    test('a day reads in full', () {
      final start = DateTime(2026, 10, 5);
      final end = DateTime(2026, 10, 6);

      expect(label(AgendaView.day, start, end, fr), 'Lundi 5 octobre 2026');
      expect(label(AgendaView.day, start, end, en), 'Monday, October 5, 2026');
    });

    test('a week within one month names the month once', () {
      final start = DateTime(2026, 10, 5);
      final end = DateTime(2026, 10, 12);

      expect(label(AgendaView.week, start, end, fr), '5 – 11 octobre 2026');
      expect(label(AgendaView.week, start, end, en), 'October 5 – 11, 2026');
    });

    test('the three rolling days of a phone end on their last day', () {
      final label3 = label(
        AgendaView.week,
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 8),
        fr,
      );

      expect(label3, '5 – 7 octobre 2026');
    });

    test('a week across two months names both', () {
      final start = DateTime(2026, 9, 28);
      final end = DateTime(2026, 10, 5);

      expect(label(AgendaView.week, start, end, fr), '28 sept. – 4 oct. 2026');
      expect(label(AgendaView.week, start, end, en), 'Sep 28 – Oct 4, 2026');
    });

    test('a week across two years gives both years', () {
      final start = DateTime(2026, 12, 28);
      final end = DateTime(2027, 1, 4);

      expect(
        label(AgendaView.week, start, end, fr),
        '28 déc. 2026 – 3 janv. 2027',
      );
      expect(
        label(AgendaView.week, start, end, en),
        'Dec 28, 2026 – Jan 3, 2027',
      );
    });

    test('the month grid is named after its month, not its edge days', () {
      // La grille d'octobre 2026 commence le lundi 28 septembre et finit
      // le dimanche 8 novembre.
      final start = DateTime(2026, 9, 28);
      final end = DateTime(2026, 11, 9);

      expect(label(AgendaView.month, start, end, fr), 'Octobre 2026');
      expect(label(AgendaView.month, start, end, en), 'October 2026');
    });

    test('a schedule page is named after its month', () {
      final start = DateTime(2026, 10, 1);
      final end = DateTime(2026, 10, 31);

      expect(label(AgendaView.schedule, start, end, fr), 'Octobre 2026');
    });
  });

  group('AgendaToolbar', () {
    Future<KalenderController> pumpToolbar(
      WidgetTester tester, {
      required double width,
    }) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = KalenderController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                AgendaToolbar(
                  keys: _keys,
                  view: AgendaView.week,
                  onViewChanged: (_) {},
                  controller: controller,
                  trailing: [
                    IconButton(
                      key: _actionKey,
                      icon: const Icon(Icons.event_note_outlined),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return controller;
    }

    Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

    final views = find.byType(SegmentedButton<AgendaView>);

    testWidgets(
      'on a phone, one line: the period first, then the controls and views',
      (tester) async {
        await pumpToolbar(tester, width: 400);

        final period = rectOf(tester, find.byKey(_keys.period));
        final today = rectOf(tester, find.byKey(_keys.today));
        final menu = rectOf(tester, find.byKey(_keys.viewMenu));
        final action = rectOf(tester, find.byKey(_actionKey));
        expect(views, findsNothing);
        expect(period.right, lessThanOrEqualTo(today.left));
        expect(today.center.dy, moreOrLessEquals(period.center.dy, epsilon: 1));
        expect(menu.center.dy, moreOrLessEquals(today.center.dy, epsilon: 1));
        expect(action.left, greaterThanOrEqualTo(menu.right));
        expect(action.right, lessThan(400));
        expect(
          rectOf(tester, find.byType(AgendaToolbar)).height,
          kToolbarHeight,
        );
      },
    );

    testWidgets('a narrow phone fits the toolbar without overflowing', (
      tester,
    ) async {
      await pumpToolbar(tester, width: 320);

      expect(tester.takeException(), isNull);
      expect(
        rectOf(tester, find.byKey(_actionKey)).right,
        lessThanOrEqualTo(320),
      );
    });

    // La police des tests donne 1 em à chaque glyphe : les libellés y sont
    // bien plus larges qu'à l'écran, d'où des largeurs généreuses ici.
    testWidgets('on a wide screen, the navigation is centred', (tester) async {
      await pumpToolbar(tester, width: 1600);

      final today = rectOf(tester, find.byKey(_keys.today));
      expect(today.center.dx, moreOrLessEquals(800, epsilon: 1));
      expect(rectOf(tester, views).center.dy, today.center.dy);
    });

    testWidgets(
      'when centring does not fit, the navigation moves aside without '
      'covering views or actions',
      (tester) async {
        await pumpToolbar(tester, width: 1200);

        final today = rectOf(tester, find.byKey(_keys.today));
        final segmented = rectOf(tester, views);
        final action = rectOf(tester, find.byKey(_actionKey));
        expect(
          segmented.center.dy,
          moreOrLessEquals(today.center.dy, epsilon: 1),
        );
        expect(segmented.right, lessThan(today.left));
        expect(action.left, greaterThan(today.right));
      },
    );

    testWidgets('the period follows the range kalender shows', (tester) async {
      final controller = await pumpToolbar(tester, width: 400);

      controller.visibleDateTimeRange.value = KalenderDateTimeRange(
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 12),
      );
      // Lue à la fin de l'image, puis affichée à la suivante.
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(_keys.period),
          matching: find.text('5 – 11 octobre 2026'),
        ),
        findsOneWidget,
      );
      // Sur un téléphone, la période ouvre la ligne, à gauche.
      final period = rectOf(tester, find.byKey(_keys.period));
      expect(period.left, moreOrLessEquals(16, epsilon: 1));
    });
  });
}

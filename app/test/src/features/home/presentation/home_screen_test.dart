import 'package:agora/src/app.dart';
import 'package:agora/src/composition_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: prodOverrides,
      child: AgoraApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('boots under the production overrides, in French', (
    tester,
  ) async {
    await _pumpApp(tester, const Locale('fr'));

    expect(find.text('Agora'), findsOneWidget);
    expect(find.text('Vos agendas, ensemble.'), findsOneWidget);
  });

  testWidgets('speaks English when the locale is English', (tester) async {
    await _pumpApp(tester, const Locale('en'));

    expect(find.text('Your calendars, together.'), findsOneWidget);
  });
}

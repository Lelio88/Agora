/// Widget racine d'Agora : thème, langues (FR par défaut, EN) et routeur.
///
/// [locale] n'est renseigné que par les tests ; en usage réel, la langue suit
/// celle de l'appareil et retombe sur le français quand elle n'est pas prise
/// en charge.
library;

import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Couleur de base provisoire, en attendant une direction artistique.
const _seedColor = Color(0xFF3F51B5);

class AgoraApp extends ConsumerWidget {
  const AgoraApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: _resolveLocale,
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  ),
);

/// Langue de l'appareil si elle est prise en charge, français sinon.
Locale _resolveLocale(Locale? device, Iterable<Locale> supported) {
  for (final locale in supported) {
    if (locale.languageCode == device?.languageCode) return locale;
  }
  return const Locale('fr');
}

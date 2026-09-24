/// Widget racine d'Agora : thème, langues (FR par défaut, EN), routeur et
/// écran d'introduction.
///
/// Langue retenue, dans l'ordre : [locale] (forcée par les tests), celle du
/// profil une fois connecté, celle de l'appareil, et le français en dernier
/// recours.
library;

import 'package:agora/src/features/intro/presentation/intro_gate.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Couleur de base provisoire, en attendant une direction artistique.
const _seedColor = Color(0xFF3F51B5);

class AgoraApp extends ConsumerWidget {
  const AgoraApp({super.key, this.locale, this.intro = true});

  final Locale? locale;

  /// L'écran d'introduction. **Faux dans les tests** : une animation de deux
  /// secondes ferait expirer chaque `pumpAndSettle`, dans deux cent trente
  /// tests qui n'ont rien à voir avec elle. `intro_test.dart` la rallume.
  final bool intro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileLanguage = ref.watch(
      currentProfileProvider.select((profile) => profile.value?.language),
    );
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale:
          locale ??
          (profileLanguage == null ? null : Locale(profileLanguage.name)),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: _resolveLocale,
      routerConfig: ref.watch(goRouterProvider),
      // `builder` plutôt qu'une route : l'intro recouvre l'app où qu'elle
      // ouvre — connexion ou agenda selon la session — sans entrer dans
      // l'historique de navigation ni pouvoir être retrouvée par un lien.
      builder: intro
          ? (context, child) => IntroGate(child: child ?? const SizedBox())
          : null,
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

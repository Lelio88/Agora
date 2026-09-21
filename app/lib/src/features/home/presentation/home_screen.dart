/// Écran d'accueil : l'agenda de la personne, et l'accès au profil.
library;

import 'package:agora/src/features/calendar/presentation/calendar_screen.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class HomeKeys {
  static const screen = ValueKey('home.screen');
  static const profileButton = ValueKey('home.profileButton');
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: HomeKeys.screen,
      appBar: AppBar(
        title: Text(l10n.agendaTitle),
        actions: [
          IconButton(
            key: HomeKeys.profileButton,
            tooltip: l10n.profileTooltip,
            icon: const Icon(Icons.account_circle_outlined),
            // push, pas go : le profil se referme par le bouton retour.
            onPressed: () => context.pushNamed(AppRoute.profile.name),
          ),
        ],
      ),
      body: const CalendarScreen(),
    );
  }
}

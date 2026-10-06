/// Écran d'accueil : trois onglets — l'agenda de la personne, « Social »
/// (ses proches et ses groupes) et « Moi » (profil et réglages).
///
/// Les onglets vivent dans une `IndexedStack` : passer de l'un à l'autre
/// garde la page, la vue et le défilement de l'agenda. Le profil est un
/// onglet plutôt qu'une icône en haut à droite : on le trouve sans le
/// chercher.
library;

import 'package:agora/src/features/calendar/presentation/calendar_screen.dart';
import 'package:agora/src/features/home/presentation/social_screen.dart';
import 'package:agora/src/features/profile/presentation/profile_screen.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

abstract final class HomeKeys {
  static const screen = ValueKey('home.screen');
  static const agendaTab = ValueKey('home.tab.agenda');
  static const socialTab = ValueKey('home.tab.social');
  static const meTab = ValueKey('home.tab.me');
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: HomeKeys.screen,
      appBar: AppBar(
        title: Text(switch (_tab) {
          0 => l10n.agendaTitle,
          1 => l10n.navSocial,
          _ => l10n.navMe,
        }),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [CalendarScreen(), SocialScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        destinations: [
          NavigationDestination(
            key: HomeKeys.agendaTab,
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: l10n.navAgenda,
          ),
          NavigationDestination(
            key: HomeKeys.socialTab,
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: l10n.navSocial,
          ),
          NavigationDestination(
            key: HomeKeys.meTab,
            icon: const Icon(Icons.account_circle_outlined),
            selectedIcon: const Icon(Icons.account_circle),
            label: l10n.navMe,
          ),
        ],
      ),
    );
  }
}

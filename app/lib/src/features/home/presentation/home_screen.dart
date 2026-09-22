/// Écran d'accueil : deux onglets, l'agenda de la personne et ses groupes,
/// et l'accès au profil.
///
/// Les onglets vivent dans une `IndexedStack` : passer de l'un à l'autre
/// garde la page, la vue et le défilement de l'agenda.
library;

import 'package:agora/src/features/calendar/presentation/calendar_screen.dart';
import 'package:agora/src/features/groups/presentation/groups_screen.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class HomeKeys {
  static const screen = ValueKey('home.screen');
  static const profileButton = ValueKey('home.profileButton');
  static const agendaTab = ValueKey('home.tab.agenda');
  static const groupsTab = ValueKey('home.tab.groups');
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
        title: Text(_tab == 0 ? l10n.agendaTitle : l10n.groupsTitle),
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
      body: IndexedStack(
        index: _tab,
        children: const [CalendarScreen(), GroupsScreen()],
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
            key: HomeKeys.groupsTab,
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: l10n.navGroups,
          ),
        ],
      ),
    );
  }
}

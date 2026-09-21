/// Écran d'accueil provisoire. L'agenda de la semaine le remplacera quand les
/// features `calendar` et `groups` seront en place.
library;

import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.appTitle, style: textTheme.displayMedium),
              const SizedBox(height: 12),
              Text(l10n.homeTagline, style: textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

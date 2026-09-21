/// Écran d'accueil provisoire : salutation et accès au profil. L'agenda de la
/// semaine le remplacera avec les features `calendar` et `groups`.
library;

import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class HomeKeys {
  static const screen = ValueKey('home.screen');
  static const profileButton = ValueKey('home.profileButton');
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final name = ref.watch(currentProfileProvider).value?.displayName;
    return Scaffold(
      key: HomeKeys.screen,
      appBar: AppBar(
        title: Text(l10n.appTitle),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (name != null)
                Text(l10n.homeGreeting(name), style: text.headlineSmall),
              const SizedBox(height: 12),
              Text(l10n.homeTagline, style: text.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Temps de trajet sur la fiche d'un rdv qui a un lieu : depuis le domicile,
/// en voiture et à pied, le mode retenu, l'heure de départ et le lieu
/// reconnu. Toucher un mode le choisit pour ce rdv (toute la série pour une
/// série) ; « Pas de trajet » retire la bande de l'agenda.
///
/// Choix non évidents :
/// - les deux durées s'affichent toujours : c'est en les comparant qu'on
///   choisit ; le mode retenu (choix du rdv, sinon réglage) est surligné ;
/// - le lieu reconnu est écrit en clair (« Vers Gare de Reims, 51100
///   Reims ») : un lieu de rdv est du texte libre, et l'on doit pouvoir
///   voir que le calcul vise le bon endroit ;
/// - sans domicile, la fiche invite à en poser un plutôt que de se taire.
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/directions/application/directions_providers.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:agora/src/features/directions/presentation/directions_keys.dart';
import 'package:agora/src/features/directions/presentation/travel_controller.dart';
import 'package:agora/src/features/directions/presentation/travel_labels.dart';
import 'package:agora/src/features/directions/presentation/travel_screen.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TravelTimes extends ConsumerWidget {
  const TravelTimes({
    required this.eventKey,
    required this.location,
    required this.start,
    required this.isAllDay,
    super.key,
  });

  /// Le rdv, ou le rdv maître de sa série : la clé de son choix.
  final String eventKey;
  final String location;
  final DateTime start;
  final bool isAllDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = location.trim();
    if (place.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(travelSettingsProvider)) {
      AsyncData(value: null) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: DirectionsKeys.setHomeHint,
          onPressed: () => TravelScreen.show(context),
          icon: const Icon(Icons.home_outlined),
          label: Text(l10n.travelSetHomeHint),
        ),
      ),
      AsyncData(value: final settings?) => _Times(
        settings: settings,
        target: (eventKey: eventKey, location: place),
        start: start,
        isAllDay: isAllDay,
      ),
      // Réglages en chargement ou illisibles : la fiche reste lisible.
      _ => const SizedBox.shrink(),
    };
  }
}

class _Times extends ConsumerWidget {
  const _Times({
    required this.settings,
    required this.target,
    required this.start,
    required this.isAllDay,
  });

  final TravelSettings settings;
  final TravelTarget target;
  final DateTime start;
  final bool isAllDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    return switch (ref.watch(placeProvider(target.location))) {
      AsyncData(value: final Address place) => _choices(context, ref, place),
      AsyncData() => Text(
        l10n.travelPlaceUnknown,
        key: DirectionsKeys.placeUnknown,
        style: small,
      ),
      AsyncError(:final error) => Text(
        messageForError(error, l10n),
        style: small,
      ),
      _ => Text(l10n.travelComputing, style: small),
    };
  }

  Widget _choices(BuildContext context, WidgetRef ref, Address place) {
    final l10n = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final locale = Localizations.localeOf(context).toString();
    final from = roundedOrigin(settings.home);
    AsyncValue<Duration?> by(TravelMode mode) => ref.watch(
      routeDurationProvider((from: from, to: pointOf(place), mode: mode)),
    );
    final choice = ref.watch(travelChoicesProvider).value?[target.eventKey];
    final estimate = ref.watch(eventTravelProvider(target)).value;
    final selected =
        choice ??
        switch (estimate?.mode) {
          TravelMode.car => TravelChoice.car,
          TravelMode.walk => TravelChoice.walk,
          null => null,
        };
    final isBusy = ref.watch(travelControllerProvider).isLoading;

    String label(AsyncValue<Duration?> duration) => switch (duration) {
      AsyncData(value: final Duration value) => travelDurationLabel(
        value,
        l10n,
      ),
      AsyncData() => l10n.travelNoRoute,
      // Réseau, ou limite du service : rien ne dit qu'il n'y a pas de chemin.
      AsyncError() => l10n.travelUnavailable,
      _ => '…',
    };

    Widget chip(TravelChoice option, IconData icon, String text) => ChoiceChip(
      key: DirectionsKeys.choice(option),
      avatar: Icon(icon, size: 18),
      label: Text(text),
      selected: selected == option,
      onSelected: isBusy || selected == option
          ? null
          : (_) => _choose(context, ref, option),
    );

    final departure = estimate == null || isAllDay
        ? null
        : departureFor(start.toLocal(), estimate.duration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            chip(
              TravelChoice.car,
              travelModeIcon(TravelMode.car),
              label(by(TravelMode.car)),
            ),
            chip(
              TravelChoice.walk,
              travelModeIcon(TravelMode.walk),
              label(by(TravelMode.walk)),
            ),
            chip(TravelChoice.none, Icons.block, l10n.travelNoTrip),
          ],
        ),
        if (departure != null)
          Text(
            l10n.travelDeparture(DateFormat.Hm(locale).format(departure)),
            key: DirectionsKeys.departure,
          ),
        Text(l10n.travelToward(place.label), style: small),
      ],
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    TravelChoice option,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final chosen = await ref
        .read(travelControllerProvider.notifier)
        .choose(target.eventKey, option);
    if (chosen || !context.mounted) return;
    final error = ref.read(travelControllerProvider).error;
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    }
  }
}

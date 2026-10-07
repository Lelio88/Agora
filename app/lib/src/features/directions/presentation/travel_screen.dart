/// « Trajets » (onglet Moi) : le domicile, départ par défaut de « Y aller »
/// et des temps de trajet ; puis, une fois le domicile posé, le mode préféré
/// et l'affichage des trajets dans l'agenda.
///
/// Choix non évidents :
/// - le domicile se choisit parmi les suggestions du service d'adresses de
///   l'IGN, jamais en texte libre : son libellé est une adresse que les apps
///   d'itinéraire savent lire, et son point sert au calcul des trajets ;
/// - la recherche attend une pause de la frappe ([addressSearchDelay]) :
///   chaque lettre n'a pas à partir vers le service ;
/// - chaque réglage s'enregistre aussitôt, comme les autres réglages de
///   « Moi » ; effacer le domicile ne demande pas de confirmation : il se
///   repose en deux gestes ;
/// - l'écran entier surveille le contrôleur : la ligne du domicile disparaît
///   quand on l'efface, et ne peut donc pas porter l'issue de l'effacement.
library;

import 'dart:async';

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/section_title.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/directions/application/directions_providers.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:agora/src/features/directions/presentation/directions_keys.dart';
import 'package:agora/src/features/directions/presentation/travel_controller.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pause de la frappe après laquelle la recherche d'adresses part.
const addressSearchDelay = Duration(milliseconds: 400);

const _maxContentWidth = 560.0;

class TravelScreen extends ConsumerWidget {
  const TravelScreen({super.key});

  static Future<void> show(BuildContext context) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const TravelScreen()));

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final cleared = await ref
        .read(travelControllerProvider.notifier)
        .clearHome();
    if (!context.mounted) return;
    _announce(
      messenger,
      ref,
      l10n,
      succeeded: cleared,
      done: l10n.travelHomeCleared,
    );
  }

  Future<void> _savePreferences(
    BuildContext context,
    WidgetRef ref, {
    required TravelPreference preference,
    required bool showInAgenda,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final saved = await ref
        .read(travelControllerProvider.notifier)
        .savePreferences(preference: preference, showInAgenda: showInAgenda);
    // Réussi, le réglage se voit à l'écran : rien à annoncer.
    if (saved || !context.mounted) return;
    _announce(messenger, ref, l10n, succeeded: false, done: '');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isBusy = ref.watch(travelControllerProvider).isLoading;
    final settings = ref.watch(travelSettingsProvider);
    final small = Theme.of(context).textTheme.bodySmall;
    return Scaffold(
      key: DirectionsKeys.travelScreen,
      appBar: AppBar(title: Text(l10n.travelTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SectionTitle(l10n.travelHomeTitle),
              AsyncValueWidget<TravelSettings?>(
                value: settings,
                data: (settings) => settings == null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(l10n.travelNoHome),
                      )
                    : ListTile(
                        key: DirectionsKeys.home,
                        leading: const Icon(Icons.home_outlined),
                        title: Text(settings.home.label),
                        trailing: IconButton(
                          key: DirectionsKeys.clearHome,
                          tooltip: l10n.travelClearHome,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: isBusy ? null : () => _clear(context, ref),
                        ),
                      ),
              ),
              _HomeSearch(isBusy: isBusy),
              if (settings.value case final settings?) ...[
                SectionTitle(l10n.travelTimesTitle),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<TravelPreference>(
                    segments: [
                      for (final (preference, icon, label) in [
                        (
                          TravelPreference.auto,
                          Icons.auto_mode,
                          l10n.travelModeAuto,
                        ),
                        (
                          TravelPreference.car,
                          Icons.directions_car_outlined,
                          l10n.travelModeCar,
                        ),
                        (
                          TravelPreference.walk,
                          Icons.directions_walk,
                          l10n.travelModeWalk,
                        ),
                      ])
                        ButtonSegment(
                          value: preference,
                          icon: Icon(icon),
                          label: Text(
                            label,
                            key: DirectionsKeys.preference(preference),
                          ),
                        ),
                    ],
                    selected: {settings.preference},
                    onSelectionChanged: isBusy
                        ? null
                        : (chosen) => _savePreferences(
                            context,
                            ref,
                            preference: chosen.single,
                            showInAgenda: settings.showInAgenda,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(l10n.travelModeAutoHelper, style: small),
                ),
                SwitchListTile(
                  key: DirectionsKeys.showInAgenda,
                  title: Text(l10n.travelShowInAgenda),
                  subtitle: Text(l10n.travelShowInAgendaHelper),
                  value: settings.showInAgenda,
                  onChanged: isBusy
                      ? null
                      : (show) => _savePreferences(
                          context,
                          ref,
                          preference: settings.preference,
                          showInAgenda: show,
                        ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(l10n.travelHomePrivacy, style: small),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Annonce l'issue d'un changement : [done] s'il a réussi, l'erreur du
/// contrôleur sinon.
void _announce(
  ScaffoldMessengerState messenger,
  WidgetRef ref,
  AppLocalizations l10n, {
  required bool succeeded,
  required String done,
}) {
  final error = succeeded ? null : ref.read(travelControllerProvider).error;
  if (!succeeded && error == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(error == null ? done : messageForError(error, l10n)),
    ),
  );
}

/// Le champ de recherche et ses suggestions ; toucher une suggestion la
/// pose comme domicile.
class _HomeSearch extends ConsumerStatefulWidget {
  const _HomeSearch({required this.isBusy});

  /// Un changement est en cours : les suggestions attendent.
  final bool isBusy;

  @override
  ConsumerState<_HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends ConsumerState<_HomeSearch> {
  final _text = TextEditingController();
  Timer? _pause;

  /// Le texte cherché, posé une fois la frappe en pause.
  String _query = '';

  @override
  void dispose() {
    _pause?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _pause?.cancel();
    _pause = Timer(
      addressSearchDelay,
      () => setState(() => _query = value.trim()),
    );
  }

  Future<void> _pick(Address address) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final typed = _text.text;
    final saved = await ref
        .read(travelControllerProvider.notifier)
        .saveHome(address);
    if (!mounted) return;
    // Une saisie reprise pendant l'enregistrement n'est pas effacée.
    if (saved && _text.text == typed) {
      _pause?.cancel();
      _text.clear();
      FocusScope.of(context).unfocus();
      setState(() => _query = '');
    }
    _announce(
      messenger,
      ref,
      l10n,
      succeeded: saved,
      done: l10n.travelHomeSaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            key: DirectionsKeys.homeField,
            controller: _text,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: l10n.travelHomeSearchLabel,
              helperText: l10n.travelHomeSearchHelper,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        if (isSearchableAddress(_query)) _suggestions(l10n),
      ],
    );
  }

  Widget _suggestions(AppLocalizations l10n) {
    const padding = EdgeInsets.fromLTRB(16, 12, 16, 0);
    return switch (ref.watch(addressSuggestionsProvider(_query))) {
      AsyncData(:final value) when value.isEmpty => Padding(
        padding: padding,
        child: Text(l10n.travelNoAddressFound),
      ),
      AsyncData(:final value) => Column(
        children: [
          for (final (index, address) in value.indexed)
            ListTile(
              key: DirectionsKeys.suggestion(index),
              leading: const Icon(Icons.place_outlined),
              title: Text(address.label),
              onTap: widget.isBusy ? null : () => _pick(address),
            ),
        ],
      ),
      AsyncError(:final error) => Padding(
        padding: padding,
        child: Text(
          messageForError(error, l10n),
          key: DirectionsKeys.searchError,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      _ => const Padding(padding: padding, child: LinearProgressIndicator()),
    };
  }
}

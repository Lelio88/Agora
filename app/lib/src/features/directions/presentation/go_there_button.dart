/// Bouton « Y aller » d'une fiche de rdv qui a un lieu : ouvre une feuille
/// où l'on choisit son app d'itinéraire, et au besoin une autre adresse de
/// départ que sa position.
///
/// Choix non évidents :
/// - l'adresse de départ vit le temps de la feuille : ni profil, ni base,
///   ni préférence locale. La refermer l'oublie ;
/// - « Autre app de cartes » (lien `geo:`) n'existe que sur Android : un
///   navigateur ne sait pas l'ouvrir.
library;

import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/features/directions/domain/directions.dart';
import 'package:agora/src/features/directions/presentation/directions_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GoThereButton extends StatelessWidget {
  const GoThereButton({
    required this.location,
    required this.start,
    required this.isAllDay,
    super.key,
  });

  /// Le lieu du rdv ; le bouton n'est pas affiché s'il est vide.
  final String location;
  final DateTime start;
  final bool isAllDay;

  @override
  Widget build(BuildContext context) {
    if (location.trim().isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: DirectionsKeys.goThere,
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _GoThereSheet(
            destination: location,
            arriveBy: wantedArrival(
              start: start,
              isAllDay: isAllDay,
              now: DateTime.now(),
            ),
          ),
        ),
        icon: const Icon(Icons.directions_transit_outlined),
        label: Text(l10n.goThereButton),
      ),
    );
  }
}

class _GoThereSheet extends ConsumerStatefulWidget {
  const _GoThereSheet({required this.destination, required this.arriveBy});

  final String destination;
  final DateTime? arriveBy;

  @override
  ConsumerState<_GoThereSheet> createState() => _GoThereSheetState();
}

class _GoThereSheetState extends ConsumerState<_GoThereSheet> {
  final _origin = TextEditingController();

  @override
  void dispose() {
    _origin.dispose();
    super.dispose();
  }

  Future<void> _open(DirectionsApp app) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final link = directionsLink(
      app,
      Trip(
        destination: widget.destination,
        origin: _origin.text,
        arriveBy: widget.arriveBy,
      ),
    );
    final opened = await ref.read(linkOpenerProvider).open(link);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.goThereFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final arriveBy = widget.arriveBy?.toLocal();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.goThereTitle, style: text.titleLarge),
            const SizedBox(height: 4),
            Text(widget.destination, style: text.bodyLarge),
            if (arriveBy != null)
              Text(
                l10n.goThereArriveBy(
                  '${DateFormat.MMMEd(locale).format(arriveBy)} · '
                  '${DateFormat.Hm(locale).format(arriveBy)}',
                ),
                key: DirectionsKeys.arriveBy,
                style: text.bodyMedium,
              ),
            const SizedBox(height: 16),
            TextField(
              key: DirectionsKeys.origin,
              controller: _origin,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.goThereOriginLabel,
                helperText: l10n.goThereOriginHelper,
                prefixIcon: const Icon(Icons.trip_origin),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: DirectionsKeys.citymapper,
              onPressed: () => _open(DirectionsApp.citymapper),
              icon: const Icon(Icons.directions_transit),
              label: Text(l10n.goThereCitymapper),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: DirectionsKeys.googleMaps,
              onPressed: () => _open(DirectionsApp.googleMaps),
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.goThereGoogleMaps),
            ),
            if (arriveBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.goThereGoogleNote, style: text.bodySmall),
              ),
            if (!kIsWeb) ...[
              const SizedBox(height: 8),
              TextButton(
                key: DirectionsKeys.otherApp,
                onPressed: () => _open(DirectionsApp.other),
                child: Text(l10n.goThereOtherApp),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La bande de trajet de l'agenda : une tuile pâle juste avant un rdv,
/// aussi haute que le trajet depuis le domicile. Son bord haut est l'heure
/// de départ.
///
/// Choix non évidents :
/// - c'est un événement de kalender à part ([TravelEvent]), qui ne se
///   touche ni ne se déplace : la tuile d'un rdv ne peut pas déborder
///   au-dessus de son propre créneau ;
/// - un trajet qui chevauche le rdv précédent partage la colonne avec lui,
///   comme deux rdv qui se chevauchent : le conflit se voit ;
/// - au-delà de [maxStripDuration], pas de bande : une demi-journée de
///   marche écraserait la journée. La fiche du rdv donne la durée.
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:agora/src/features/directions/presentation/directions_keys.dart';
import 'package:agora/src/features/directions/presentation/travel_labels.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kalender/kalender.dart';

/// Trajet le plus long que l'agenda dessine.
const maxStripDuration = Duration(hours: 3);

final class TravelEvent extends KalenderEvent {
  TravelEvent(AgendaItem item, TravelEstimate estimate)
    : this._(
        item,
        estimate,
        item.localStart.subtract(estimate.duration),
        item.localStart,
      );

  TravelEvent._(this.item, this.estimate, DateTime start, DateTime end)
    : super(
        id: 'travel:${item.instanceKey}',
        start: start,
        end: end,
        isAllDay: false,
        interaction: EventInteraction.fromCanModify(false),
      );

  /// Le rdv auquel mène le trajet.
  final AgendaItem item;
  final TravelEstimate estimate;

  @override
  TravelEvent copyWithData({required DateTime start, required DateTime end}) =>
      TravelEvent._(item, estimate, start, end);
}

class TravelStrip extends StatelessWidget {
  const TravelStrip(this.event, {super.key});

  final TravelEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final duration = travelDurationLabel(event.estimate.duration, l10n);
    final leave = DateFormat.Hm(locale)
        .format(departureFor(event.item.localStart, event.estimate.duration));
    return Container(
      key: DirectionsKeys.strip(event.item.instanceKey),
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Semantics(
        label: l10n.travelStripSemantics(duration, leave),
        excludeSemantics: true,
        child: LayoutBuilder(
          // Un trajet de quelques minutes n'a pas la place d'une ligne.
          builder: (context, constraints) => constraints.maxHeight < 14
              ? const SizedBox.expand()
              : Row(
                  children: [
                    Icon(
                      travelModeIcon(event.estimate.mode),
                      size: 12,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        l10n.travelStripLabel(duration, leave),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Pont entre une instance de l'agenda ([AgendaItem]) et le modèle de
/// `kalender` ([KalenderEvent]). Chaque instance garde son objet d'origine,
/// pour que l'appui sur une tuile remonte au bon rdv et au bon créneau, et
/// son agenda, pour la couleur de la tuile et le droit de la déplacer.
///
/// Invariant : pendant un glisser-déposer, kalender copie l'événement avec de
/// nouvelles dates ([copyWithData]) ; la copie garde le même [item]. Les
/// nouvelles dates se lisent sur la copie ([start], [end]), jamais sur
/// [item], qui décrit le rdv tel qu'il est en base.
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:kalender/kalender.dart';

final class AgendaEvent extends KalenderEvent {
  // kalender affiche chaque instant en heure locale : une journée entière
  // doit lui arriver en minuit LOCAL, sinon elle glisse sur la veille dans
  // un fuseau négatif.
  AgendaEvent(AgendaItem item, {UserCalendar? calendar})
    : this._(item, calendar, item.localStart, item.localEnd);

  AgendaEvent._(this.item, this.calendar, DateTime start, DateTime end)
    : super(
        id: item.instanceKey,
        start: start,
        end: end,
        isAllDay: item.isAllDay,
        // Seuls les rdv d'un agenda où l'on écrit se déplacent ou s'étirent.
        interaction: EventInteraction.fromCanModify(
          calendar?.isWritable ?? false,
        ),
      );

  final AgendaItem item;

  /// Agenda du rdv, `null` tant que la liste des agendas n'est pas chargée.
  final UserCalendar? calendar;

  @override
  AgendaEvent copyWithData({required DateTime start, required DateTime end}) =>
      AgendaEvent._(item, calendar, start, end);
}

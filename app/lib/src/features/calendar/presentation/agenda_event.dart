/// Pont entre une instance de l'agenda ([AgendaItem]) et le modèle de
/// `kalender` ([KalenderEvent]). Chaque instance garde son objet d'origine,
/// pour que l'appui sur une tuile remonte au bon rdv et au bon créneau.
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:kalender/kalender.dart';

final class AgendaEvent extends KalenderEvent {
  AgendaEvent(this.item)
    : super(
        id: item.instanceKey,
        // kalender affiche chaque instant en heure locale : une journée
        // entière doit lui arriver en minuit LOCAL, sinon elle glisse sur
        // la veille dans un fuseau négatif.
        start: item.localStart,
        end: item.localEnd,
        isAllDay: item.isAllDay,
        // Le déplacement se fait par l'éditeur : un glisser-déposer
        // devrait poser la question « occurrence ou série ».
        interaction: EventInteraction.fromCanModify(false),
      );

  final AgendaItem item;

  /// Exigé par kalender pour ses copies internes (glisser-déposer). Les
  /// tuiles sont verrouillées : l'objet métier reste le même.
  @override
  AgendaEvent copyWithData({required DateTime start, required DateTime end}) =>
      AgendaEvent(item);
}

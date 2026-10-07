/// Les rdv de mon agenda auxquels l'agenda ajoute le trajet depuis mon
/// domicile.
///
/// Choix non évidents :
/// - un rdv d'un agenda de proche n'en a jamais : c'est le rdv de quelqu'un
///   d'autre (ses repos, son anniversaire), pas un endroit où j'irai ;
/// - un rdv de groupe n'en a que si j'ai répondu présent ou peut-être :
///   sans réponse, rien ne dit que j'y vais ;
/// - une journée entière n'a pas d'heure d'arrivée.
///
/// Invariant : fonction pure.
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';

/// Vrai si [item], rangé dans [calendar], reçoit son trajet dans l'agenda.
bool needsTravel(AgendaItem item, UserCalendar? calendar) {
  if (item.isAllDay || (item.location?.trim() ?? '').isEmpty) return false;
  if (calendar == null || calendar.isContact) return false;
  if (calendar.isPersonal) return true;
  return switch (item.myResponse) {
    ResponseStatus.yes || ResponseStatus.maybe => true,
    _ => false,
  };
}

/// La clé du choix de mode de [item] : son rdv, ou le rdv maître de sa
/// série (un choix vaut pour toute la série).
String travelKeyOf(AgendaItem item) => item.seriesId ?? item.eventId;

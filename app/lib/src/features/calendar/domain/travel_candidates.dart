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

/// Les [AgendaItem.instanceKey] des rdv de [candidates] (ceux qui passent
/// [needsTravel]) qui n'ont pas de trajet à eux : on y est déjà, car le rdv
/// précédent, le même jour, a lieu à la même adresse (casse et espaces
/// ignorés). Un rdv à une autre adresse entre les deux, ou un autre jour,
/// rend son trajet au suivant.
Set<String> followUpsAtSamePlace(Iterable<AgendaItem> candidates) {
  final sorted = candidates.toList()
    ..sort((a, b) => a.localStart.compareTo(b.localStart));
  final skipped = <String>{};
  AgendaItem? previous;
  for (final item in sorted) {
    if (previous != null &&
        _sameDay(previous.localStart, item.localStart) &&
        _placeOf(previous) == _placeOf(item)) {
      skipped.add(item.instanceKey);
    }
    previous = item;
  }
  return skipped;
}

String _placeOf(AgendaItem item) =>
    (item.location ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// La clé du choix de mode de [item] : son rdv, ou le rdv maître de sa
/// série (un choix vaut pour toute la série).
String travelKeyOf(AgendaItem item) => item.seriesId ?? item.eventId;

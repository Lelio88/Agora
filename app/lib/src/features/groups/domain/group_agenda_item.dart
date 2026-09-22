/// Un créneau de l'agenda d'un groupe, tel que `group_agenda()` le rend
/// après la règle de vie privée : celui d'un membre (avec son titre s'il
/// partage le détail, « occupé » sinon), ou un rdv de l'agenda du groupe.
///
/// Invariant : [title] et [location] ne sont non nuls qu'au niveau
/// [ShareLevel.details] ; un créneau « invisible » n'arrive jamais ici.
library;

import 'package:agora/src/features/groups/domain/group.dart';

final class GroupAgendaItem {
  const GroupAgendaItem({
    required this.level,
    required this.start,
    required this.end,
    required this.isAllDay,
    this.eventId,
    this.userId,
    this.isGroupEvent = false,
    this.title,
    this.location,
  });

  /// Nul si le détail n'est pas partagé.
  final String? eventId;

  /// Membre à qui appartient le créneau ; nul pour un rdv du groupe.
  final String? userId;
  final bool isGroupEvent;
  final ShareLevel level;
  final String? title;
  final String? location;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;

  bool get isBusyOnly => level != ShareLevel.details;

  /// Clé d'affichage : l'identifiant n'est pas toujours connu (créneau
  /// « occupé »), le membre et l'horaire le remplacent.
  String get instanceKey =>
      '${eventId ?? 'busy'}|${userId ?? 'group'}|${start.toIso8601String()}';

  /// Début à afficher (voir `AgendaItem.localStart` : une journée entière
  /// se lit sur ses composants UTC, jamais par `toLocal()`).
  DateTime get localStart => isAllDay ? _calendarDate(start) : start.toLocal();

  DateTime get localEnd => isAllDay ? _calendarDate(end) : end.toLocal();

  static DateTime _calendarDate(DateTime instant) {
    final utc = instant.toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }
}

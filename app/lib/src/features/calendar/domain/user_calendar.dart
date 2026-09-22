/// Un agenda que l'utilisateur peut lire : les siens (natifs, ou importés
/// par lien iCal) et, plus tard, ceux de ses groupes, avec sa préférence
/// d'affichage.
///
/// Deux réglages à ne pas confondre :
/// - [visibility] est de la **vie privée** : ce que les membres de ses
///   groupes voient des rdv de cet agenda (`null` : selon le groupe) ;
/// - [hidden] est un **affichage** : l'agenda disparaît de sa propre vue,
///   sans rien changer pour les autres.
library;

import 'package:agora/src/features/calendar/domain/event_visibility.dart';

enum CalendarKind { native, ics }

final class UserCalendar {
  const UserCalendar({
    required this.id,
    required this.name,
    required this.kind,
    this.colorHex,
    this.visibility,
    this.groupId,
    this.hidden = false,
  });

  final String id;
  final String name;
  final CalendarKind kind;

  /// Couleur `#RRGGBB`, ou `null` pour la couleur par défaut de l'app.
  final String? colorHex;
  final EventVisibility? visibility;

  /// Groupe propriétaire, `null` pour un agenda personnel.
  final String? groupId;
  final bool hidden;

  bool get isPersonal => groupId == null;

  /// On peut y ranger ses rdv et les modifier : un agenda natif à soi (un
  /// agenda iCal est en lecture seule, ceux des groupes arrivent plus tard).
  bool get isWritable => kind == CalendarKind.native && isPersonal;

  UserCalendar copyWith({bool? hidden}) => UserCalendar(
    id: id,
    name: name,
    kind: kind,
    colorHex: colorHex,
    visibility: visibility,
    groupId: groupId,
    hidden: hidden ?? this.hidden,
  );
}

/// Ce que l'utilisateur règle en créant ou en modifiant un agenda.
final class CalendarDraft {
  const CalendarDraft({required this.name, this.colorHex, this.visibility})
    : assert(
        visibility != EventVisibility.details,
        'an agenda can only restrict what groups see',
      );

  final String name;
  final String? colorHex;
  final EventVisibility? visibility;
}

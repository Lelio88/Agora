/// Un agenda que l'utilisateur peut lire : les siens (natifs, ou importés
/// par lien iCal) et, plus tard, ceux de ses groupes, avec sa préférence
/// d'affichage.
///
/// Deux réglages à ne pas confondre :
/// - [visibility] est de la **vie privée** : ce que les membres de ses
///   groupes voient des rdv de cet agenda (`null` : selon le groupe) ;
/// - [hidden] est un **affichage** : l'agenda disparaît de sa propre vue,
///   sans rien changer pour les autres.
///
/// Un agenda importé ([CalendarKind.ics]) est en lecture seule : le worker
/// le relit depuis son lien toutes les 30 minutes. L'app n'en connaît que
/// l'état de synchro ([lastSyncedAt], [syncError]) — jamais le lien, qui
/// est un secret.
library;

import 'package:agora/src/features/calendar/domain/event_visibility.dart';

enum CalendarKind { native, ics }

/// Dernier échec de relecture d'un agenda importé, par le code que le
/// worker enregistre (`calendars.sync_error`).
enum FeedSyncError {
  unreachable('unreachable'),
  timeout('timeout'),
  notFound('not_found'),
  forbidden('forbidden'),
  httpError('http_error'),
  tooLarge('too_large'),
  notCalendar('not_calendar'),
  blockedAddress('blocked_address'),
  tooManyEvents('too_many_events'),
  unknown('unknown');

  const FeedSyncError(this.code);

  final String code;

  /// `null` sans erreur ; un code inconnu (worker plus récent) devient
  /// [unknown].
  static FeedSyncError? fromCode(String? code) => code == null
      ? null
      : FeedSyncError.values.firstWhere(
          (e) => e.code == code,
          orElse: () => FeedSyncError.unknown,
        );
}

final class UserCalendar {
  const UserCalendar({
    required this.id,
    required this.name,
    required this.kind,
    this.colorHex,
    this.visibility,
    this.groupId,
    this.hidden = false,
    this.lastSyncedAt,
    this.syncError,
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

  /// Dernière relecture réussie d'un agenda importé ; `null` avant la
  /// première.
  final DateTime? lastSyncedAt;

  /// Échec de la dernière relecture ; `null` si elle a réussi.
  final FeedSyncError? syncError;

  bool get isPersonal => groupId == null;

  bool get isImported => kind == CalendarKind.ics;

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
    lastSyncedAt: lastSyncedAt,
    syncError: syncError,
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

/// Un agenda à importer par son lien iCal (`https://` ou `webcal://`).
final class ImportedCalendarDraft {
  const ImportedCalendarDraft({
    required this.name,
    required this.url,
    this.colorHex,
  });

  final String name;

  /// Le lien : un secret, qui part au serveur et n'en revient jamais.
  final String url;
  final String? colorHex;

  @override
  String toString() => 'ImportedCalendarDraft($name)';
}

/// Aide de saisie : un lien `https://` ou `webcal://`, sans espace ni
/// identifiants, que `add_ics_calendar` acceptera (même motif). Le serveur
/// fait foi.
bool looksLikeFeedUrl(String input) {
  var url = input.trim();
  if (url.toLowerCase().startsWith('webcal://')) {
    url = 'https://${url.substring('webcal://'.length)}';
  }
  return url.length <= _maxFeedUrlLength && _feedUrlPattern.hasMatch(url);
}

const _maxFeedUrlLength = 2048;
final _feedUrlPattern = RegExp(
  r'^https://[^/\s@]+(/\S*)?$',
  caseSensitive: false,
);

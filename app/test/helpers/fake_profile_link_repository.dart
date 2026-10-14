import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/profile_link/domain/profile_link.dart';
import 'package:agora/src/features/profile_link/domain/profile_link_repository.dart';

import 'fake_calendars_repository.dart';

/// Faux [ProfileLinkRepository] en mémoire. Comme le serveur : vingt liens au
/// plus, un lien inconnu est refusé sans dire pourquoi, on n'ouvre pas son
/// propre lien, et ouvrir deux fois le lien d'une même personne rend le même
/// proche (créé dans le faux dépôt d'agendas, s'il est fourni).
class FakeProfileLinkRepository implements ProfileLinkRepository {
  FakeProfileLinkRepository([this.calendars]);

  /// Le faux dépôt d'agendas où naissent les proches ; le robot y branche le
  /// sien si le test n'en a pas donné.
  FakeCalendarsRepository? calendars;

  /// Les liens de l'utilisateur, du plus récent au plus ancien.
  final links = <ProfileLink>[];

  /// Les liens des autres : code → nom de la personne.
  final others = <String, String>{};

  /// Les codes ouverts, dans l'ordre.
  final imported = <String>[];

  AppException? nextError;
  final _contacts = <String, String>{};
  int _next = 1;

  void _check() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  @override
  Future<List<ProfileLink>> fetchMine() async {
    _check();
    return List.unmodifiable(links);
  }

  @override
  Future<ProfileLink> create({
    required String label,
    required ProfileLinkLevel level,
  }) async {
    _check();
    if (links.length >= 20) throw const TooManyProfileLinksException();
    final link = ProfileLink(
      code: 'MARCHE2${_next++}',
      label: label,
      level: level,
      createdAt: DateTime.utc(2026, 10, 14),
    );
    links.insert(0, link);
    return link;
  }

  @override
  Future<void> revoke(String code) async {
    _check();
    links.removeWhere((link) => link.code == code);
  }

  @override
  Future<String> previewName(String code) async {
    _check();
    return others[code] ??
        (links.any((l) => l.code == code)
            ? 'Zoé'
            : throw const InvalidProfileLinkException());
  }

  @override
  Future<String> importProfile(String code) async {
    _check();
    if (links.any((link) => link.code == code)) {
      throw const OwnProfileLinkException();
    }
    final name = others[code] ?? (throw const InvalidProfileLinkException());
    imported.add(code);
    final id = _contacts.putIfAbsent(name, () => 'cal-profile-${_next++}');
    calendars?.pushFromServer(
      UserCalendar(
        id: id,
        name: name,
        kind: CalendarKind.native,
        visibility: EventVisibility.invisible,
        isContact: true,
      ),
    );
    return id;
  }
}

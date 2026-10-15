/// Liens de profil : la liste des siens, le nom derrière un lien reçu, et le
/// service qui les crée, les supprime et les ouvre.
///
/// Choix non évidents :
/// - ouvrir un lien crée ou rafraîchit un proche : le service invalide donc
///   les agendas et l'agenda de la feature agenda, pour que le proche et ses
///   rdv apparaissent tout de suite ;
/// - un lien ouvert déconnecté est retenu ([PendingProfileLink]) le temps de
///   la connexion, puis le routeur y ramène, comme pour une invitation.
library;

import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/profile_link/domain/profile_link.dart';
import 'package:agora/src/features/profile_link/domain/profile_link_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileLinkRepositoryProvider = Provider<ProfileLinkRepository>(
  (ref) => throw UnimplementedError(
    'profileLinkRepositoryProvider must be overridden at the composition root.',
  ),
);

/// Les liens de l'utilisateur ; aucun sans compte (pas de requête anonyme).
final myProfileLinksProvider = FutureProvider.autoDispose<List<ProfileLink>>((
  ref,
) async {
  final repository = ref.watch(profileLinkRepositoryProvider);
  if (await ref.watch(currentUserIdProvider.future) == null) return const [];
  return repository.fetchMine();
});

/// Mes agendas qu'un lien peut partager : sans les proches ni les agendas
/// invisibles, qui ne sortiraient pas.
final shareableCalendarsProvider =
    FutureProvider.autoDispose<List<ShareableCalendar>>((ref) async {
      final calendars = await ref.watch(calendarsProvider.future);
      return [
        for (final calendar in calendars)
          if (!calendar.isContact &&
              calendar.visibility != EventVisibility.invisible)
            ShareableCalendar(id: calendar.id, name: calendar.name),
      ];
    });

/// Le nom de la personne derrière le code d'un lien reçu.
final profileLinkNameProvider = FutureProvider.autoDispose
    .family<String, String>(
      (ref, code) => ref.watch(profileLinkRepositoryProvider).previewName(code),
    );

final class ProfileLinkService {
  const ProfileLinkService(
    this._repository,
    this._onLinksChanged,
    this._onContactChanged,
  );

  final ProfileLinkRepository _repository;
  final void Function() _onLinksChanged;
  final void Function() _onContactChanged;

  Future<ProfileLink> create({
    required String label,
    required ProfileLinkLevel level,
    required List<String> calendarIds,
  }) async {
    final link = await _repository.create(
      label: label.trim(),
      level: level,
      calendarIds: calendarIds,
    );
    _onLinksChanged();
    return link;
  }

  Future<void> revoke(String code) async {
    await _repository.revoke(code);
    _onLinksChanged();
  }

  /// Ouvre un lien reçu ; l'identifiant du proche créé ou rafraîchi.
  Future<String> open(String code) async {
    final calendarId = await _repository.importProfile(code);
    _onContactChanged();
    return calendarId;
  }
}

final profileLinkServiceProvider = Provider<ProfileLinkService>(
  (ref) => ProfileLinkService(
    ref.watch(profileLinkRepositoryProvider),
    () => ref.invalidate(myProfileLinksProvider),
    () {
      ref
        ..invalidate(calendarsProvider)
        ..invalidate(agendaProvider);
    },
  ),
);

/// Lien de profil ouvert alors que personne n'était connecté (voir
/// `auth_redirect.dart`). L'écran du lien le consomme.
final class PendingProfileLink {
  String? code;
}

final pendingProfileLinkProvider = Provider<PendingProfileLink>(
  (ref) => PendingProfileLink(),
);

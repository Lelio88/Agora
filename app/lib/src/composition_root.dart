/// Composition root : le **seul** fichier (avec `main.dart`) autorisé à
/// importer les couches `data/`.
///
/// Chaque feature déclare dans son `application/` un `*RepositoryProvider`
/// qui lève `UnimplementedError`, et l'implémentation concrète est branchée
/// ici. `composition_root_test.dart` lit chaque provider sous
/// [prodOverrides] : un branchement oublié le fait échouer.
///
/// Le client Supabase est passé en paramètre plutôt que lu dans
/// `Supabase.instance` : le test peut ainsi construire un client sans
/// initialiser le plugin ni toucher au réseau.
///
/// Après toute modification de cette liste, faire un hot **restart** (`R`) :
/// un hot reload ne réévalue pas les overrides.
library;

import 'package:agora/src/device/audioplayers_intro_sound.dart';
import 'package:agora/src/device/device_timezone.dart';
import 'package:agora/src/device/intro_sound.dart';
import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/device/platform_device_timezone.dart';
import 'package:agora/src/device/url_launcher_link_opener.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/data/supabase_auth_repository.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/data/supabase_calendar_repository.dart';
import 'package:agora/src/features/calendar/data/supabase_calendars_repository.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/data/supabase_groups_repository.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/features/profile/data/supabase_profile_repository.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<Override> prodOverrides(SupabaseClient client) => [
  authRepositoryProvider.overrideWith((ref) => SupabaseAuthRepository(client)),
  profileRepositoryProvider.overrideWith(
    (ref) => SupabaseProfileRepository(client),
  ),
  calendarRepositoryProvider.overrideWith(
    (ref) => SupabaseCalendarRepository(client),
  ),
  calendarsRepositoryProvider.overrideWith(
    (ref) => SupabaseCalendarsRepository(client),
  ),
  groupsRepositoryProvider.overrideWith(
    (ref) => SupabaseGroupsRepository(client),
  ),
  deviceTimezoneProvider.overrideWith((ref) => const PlatformDeviceTimezone()),
  linkOpenerProvider.overrideWith((ref) => const UrlLauncherLinkOpener()),
  introSoundProvider.overrideWith((ref) => AudioPlayersIntroSound()),
];

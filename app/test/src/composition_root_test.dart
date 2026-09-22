import 'package:agora/src/composition_root.dart';
import 'package:agora/src/device/device_timezone.dart';
import 'package:agora/src/device/platform_device_timezone.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/data/supabase_auth_repository.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/data/supabase_calendar_repository.dart';
import 'package:agora/src/features/calendar/data/supabase_calendars_repository.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/features/profile/data/supabase_profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('the composition root wires every repository', () {
    // Aucun appel réseau : construire un client ne contacte pas le serveur.
    final client = SupabaseClient('http://127.0.0.1:9', 'test-key');
    addTearDown(client.dispose);
    final container = ProviderContainer(overrides: prodOverrides(client));
    addTearDown(container.dispose);

    expect(
      container.read(authRepositoryProvider),
      isA<SupabaseAuthRepository>(),
    );
    expect(
      container.read(profileRepositoryProvider),
      isA<SupabaseProfileRepository>(),
    );
    expect(
      container.read(deviceTimezoneProvider),
      isA<PlatformDeviceTimezone>(),
    );
    expect(
      container.read(calendarRepositoryProvider),
      isA<SupabaseCalendarRepository>(),
    );
    expect(
      container.read(calendarsRepositoryProvider),
      isA<SupabaseCalendarsRepository>(),
    );
  });
}

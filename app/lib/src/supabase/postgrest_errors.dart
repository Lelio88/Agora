/// Traduction des erreurs PostgREST en `AppException`, partagée par les
/// dépôts Supabase (agenda, agendas, groupes).
///
/// Les RPC et triggers lèvent des messages stables (`event_not_found`,
/// `last_native_calendar`…) : c'est eux qu'on lit, jamais le texte libre.
/// Invariant : aucune `PostgrestException` ne sort d'un dépôt sans passer ici.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/network_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<T> guardPostgrest<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on PostgrestException catch (error) {
    throw switch (error.message) {
      'invalid_range' => const InvalidRangeException(),
      'event_not_found' => const EventNotFoundException(),
      'calendar_not_found' => const CalendarNotFoundException(),
      'last_native_calendar' => const LastNativeCalendarException(),
      'invite_invalid' => const InvalidInviteException(),
      'not_a_member' => const NotGroupMemberException(),
      'not_group_owner' => const NotGroupOwnerException(),
      'invalid_member' => const InvalidMemberException(),
      _ when looksLikeNetworkError(error.message) => const NetworkException(),
      _ => const UnknownException(),
    };
  } on Exception catch (error) {
    throw looksLikeNetworkError(error.toString())
        ? const NetworkException()
        : const UnknownException();
  }
}

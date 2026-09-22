/// Proposer un rdv à un groupe : l'éditeur de rdv, rangé d'office dans
/// l'agenda du groupe. Ouvert par la route `/groups/:groupId/events/new`
/// (depuis l'agenda du groupe) ; rend `true` une fois le rdv créé.
///
/// Choix non évident : l'écran du groupe (feature groupes) ne connaît ni
/// l'éditeur ni le service de l'agenda ; il ouvre cette page par son nom de
/// route, et la page fait tout, jusqu'à l'enregistrement.
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/event_actions.dart';
import 'package:agora/src/features/calendar/presentation/event_editor_screen.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupEventEditorPage extends ConsumerWidget {
  const GroupEventEditorPage({
    required this.groupId,
    this.initialStart,
    this.initialEnd,
    super.key,
  });

  final String groupId;

  /// Créneau touché dans l'agenda du groupe, ou trouvé libre.
  final DateTime? initialStart;

  /// Fin d'un créneau trouvé libre (sinon, une heure après le début).
  final DateTime? initialEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final timezone =
        ref.watch(currentProfileProvider).value?.timezone ?? 'Europe/Paris';
    return ref
        .watch(calendarsProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(messageForError(error, l10n))),
          ),
          data: (calendars) {
            final calendar = calendars
                .where((c) => c.groupId == groupId)
                .firstOrNull;
            if (calendar == null) {
              return Scaffold(
                appBar: AppBar(),
                body: Center(child: Text(l10n.errorCalendarNotFound)),
              );
            }
            return EventEditorScreen(
              calendarId: calendar.id,
              timezone: timezone,
              calendars: <UserCalendar>[calendar],
              initialStart: initialStart,
              initialEnd: initialEnd,
              onResult: (result) async => switch (result) {
                EditorSaved(:final draft) => runAction(
                  context,
                  () => ref.read(calendarServiceProvider).create(draft),
                  l10n.eventProposed,
                ),
                EditorDeleteRequested() => false,
              },
            );
          },
        );
  }
}

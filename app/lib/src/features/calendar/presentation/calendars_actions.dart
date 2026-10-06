/// Actions sur les agendas, partagées par « Mes agendas », l'onglet Social
/// et la page d'un proche : créer, importer, modifier (avec la suppression
/// confirmée et la relance d'une synchro), et en afficher l'issue.
///
/// Choix non évidents :
/// - les éditeurs ne parlent pas au serveur : ils rendent un résultat, et
///   c'est ici qu'on confirme une suppression puis qu'on appelle le service ;
/// - supprimer un agenda annonce d'abord combien de rdv partent avec lui.
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_editor_screen.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/import_calendar_screen.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Crée un agenda (celui d'un proche si [contact]) ; rend l'identifiant de
/// l'agenda créé, ou `null` si l'utilisateur renonce ou si la création
/// échoue.
Future<String?> createCalendar(
  BuildContext context,
  WidgetRef ref, {
  bool contact = false,
}) async {
  final result = await CalendarEditorScreen.show(context, contact: contact);
  if (result is! CalendarEditorSaved || !context.mounted) return null;
  final l10n = AppLocalizations.of(context);
  String? created;
  await runCalendarAction(
    context,
    () async =>
        created = await ref.read(calendarsServiceProvider).create(result.draft),
    success: contact ? l10n.contactSaved : l10n.calendarSaved,
  );
  return created;
}

/// Importe un agenda par son lien iCal ; [contact] et [name] préremplissent
/// l'écran (le planning d'un proche).
Future<void> importCalendar(
  BuildContext context,
  WidgetRef ref, {
  bool contact = false,
  String? name,
}) async {
  final draft = await ImportCalendarScreen.show(
    context,
    forContact: contact,
    name: name,
  );
  if (draft == null || !context.mounted) return;
  await runCalendarAction(
    context,
    () => ref.read(calendarsServiceProvider).import(draft),
    success: AppLocalizations.of(context).calendarImported,
  );
}

/// Ouvre l'éditeur de [calendar] et applique ce qui en sort ; vrai si
/// l'agenda a été supprimé.
Future<bool> editCalendar(
  BuildContext context,
  WidgetRef ref,
  UserCalendar calendar, {
  required bool canDelete,
}) async {
  final result = await CalendarEditorScreen.show(
    context,
    existing: calendar,
    canDelete: canDelete,
  );
  if (result == null || !context.mounted) return false;
  final l10n = AppLocalizations.of(context);
  final service = ref.read(calendarsServiceProvider);
  switch (result) {
    case CalendarEditorSaved(:final draft):
      await runCalendarAction(
        context,
        () => service.update(calendar.id, draft),
        success: l10n.calendarSaved,
      );
      return false;
    case CalendarEditorSyncRequested():
      await runCalendarAction(
        context,
        () => service.syncNow(calendar.id),
        success: l10n.syncRequested,
      );
      return false;
    case CalendarEditorDeleteRequested():
      final int count;
      try {
        count = await service.countEvents(calendar.id);
      } on Exception catch (error) {
        if (context.mounted) _showError(context, error);
        return false;
      }
      if (!context.mounted) return false;
      final confirmed = await _confirmDelete(context, calendar, count);
      if (!confirmed || !context.mounted) return false;
      return runCalendarAction(
        context,
        () => service.delete(calendar.id),
        success: l10n.calendarDeleted,
      );
  }
}

Future<bool> _confirmDelete(
  BuildContext context,
  UserCalendar calendar,
  int count,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(l10n.deleteCalendarTitle(calendar.name)),
        content: Text(l10n.deleteCalendarBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: CalendarKeys.confirmDeleteCalendar,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteCalendarButton),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// Lance [action] ; affiche [success] ou le message de l'erreur. Vrai si
/// l'action a réussi.
Future<bool> runCalendarAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } on Exception catch (error) {
    if (context.mounted) _showError(context, error);
    return false;
  }
}

void _showError(BuildContext context, Exception error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(messageForError(error, AppLocalizations.of(context))),
    ),
  );
}

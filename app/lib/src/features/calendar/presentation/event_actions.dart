/// Actions sur une instance, partagées par l'agenda et la fiche d'un rdv de
/// groupe : ouvrir l'éditeur, poser la question « cette occurrence / toute
/// la série », appeler le service et en afficher l'issue.
///
/// Invariant : la question de portée ne se pose qu'ici (et au glisser-
/// déposer de l'agenda, qui passe par [askScope]).
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/event_editor_screen.dart';
import 'package:agora/src/features/calendar/presentation/scope_dialog.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ouvre l'éditeur sur [item] (rangé dans l'un de [calendars]) ; vrai si le
/// rdv a été modifié ou supprimé.
Future<bool> editInstance(
  BuildContext context,
  WidgetRef ref,
  AgendaItem item, {
  required List<UserCalendar> calendars,
}) async {
  final result = await EventEditorScreen.show(
    context,
    calendarId: item.calendarId,
    timezone: item.timezone,
    calendars: calendars,
    existing: item,
  );
  if (result == null || !context.mounted) return false;
  switch (result) {
    case EditorSaved(:final draft):
      final target = await askScope(
        context,
        item,
        ScopeQuestion.edit,
        // Une occurrence vit dans l'agenda de sa série : changer d'agenda
        // ne peut viser que toute la série.
        allowOccurrence: draft.calendarId == item.calendarId,
      );
      if (target == null || !context.mounted) return false;
      return runAction(
        context,
        () => ref
            .read(calendarServiceProvider)
            .save(target: target, draft: draft),
        AppLocalizations.of(context).eventSaved,
      );
    case EditorDeleteRequested():
      return deleteInstance(context, ref, item);
  }
}

/// Supprime [item] (après la question de portée pour une série) ; vrai si
/// c'est fait.
Future<bool> deleteInstance(
  BuildContext context,
  WidgetRef ref,
  AgendaItem item,
) async {
  final target = await askScope(context, item, ScopeQuestion.delete);
  if (target == null || !context.mounted) return false;
  return runAction(
    context,
    () => ref.read(calendarServiceProvider).delete(target),
    AppLocalizations.of(context).eventDeleted,
  );
}

/// Pour une instance de série, demande la portée ; sinon le rdv entier.
Future<EditTarget?> askScope(
  BuildContext context,
  AgendaItem item,
  ScopeQuestion question, {
  bool allowOccurrence = true,
}) {
  if (!item.isRecurring) return Future.value(EditTarget.series(item));
  return showScopeDialog(
    context,
    item: item,
    question: question,
    allowOccurrence: allowOccurrence,
  );
}

/// Lance [action] et en affiche l'issue ; vrai si elle a réussi. L'issue
/// remplace le message précédent : deux actions rapides (changer d'avis sur
/// une réponse) ne font pas attendre la seconde derrière la première.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action,
  String success,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  void show(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  try {
    await action();
    show(success);
    return true;
  } on Exception catch (error) {
    show(messageForError(error, l10n));
    return false;
  }
}

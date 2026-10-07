/// Actions sur une instance, partagées par l'agenda et la fiche d'un rdv de
/// groupe : ouvrir l'éditeur, poser la question « cette occurrence / toute
/// la série », appeler le service et en afficher l'issue.
///
/// Choix non évident : un rdv de l'agenda d'un proche que
/// [contactFormFor] reconnaît (anniversaire, horaires de travail, congé)
/// s'ouvre dans son formulaire court, d'où qu'on l'ouvre. Il se modifie
/// alors en entier, sans la question de portée : on change la date d'un
/// anniversaire ou ses horaires, pas une séance. Supprimer un anniversaire
/// le supprime aussi en entier ; une journée de travail se supprime seule
/// si on le choisit.
///
/// Un rdv ponctuel n'a pas de question de portée, mais l'éditeur peut avoir
/// coché « appliquer aussi aux semblables » : le service recopie alors ce
/// qui a changé sur eux avant d'enregistrer le rdv.
///
/// Invariant : la question de portée ne se pose qu'ici (et au glisser-
/// déposer de l'agenda, qui passe par [askScope]).
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/contact_agenda.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/contact_event_editor.dart';
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
  final contactForm = _contactForm(item, calendars);
  final result = contactForm == null
      ? await EventEditorScreen.show(
          context,
          calendarId: item.calendarId,
          timezone: item.timezone,
          calendars: calendars,
          existing: item,
        )
      : await ContactEventEditor.show(
          context,
          kind: contactForm,
          calendarId: item.calendarId,
          timezone: item.timezone,
          existing: item,
        );
  if (result == null || !context.mounted) return false;
  switch (result) {
    case EditorSaved(:final draft, :final applyToSimilar):
      final target = contactForm != null
          ? EditTarget.series(item)
          : await askScope(
              context,
              item,
              ScopeQuestion.edit,
              // Une occurrence vit dans l'agenda de sa série : changer
              // d'agenda ne peut viser que toute la série.
              allowOccurrence: draft.calendarId == item.calendarId,
            );
      if (target == null || !context.mounted) return false;
      return runAction(
        context,
        () => ref
            .read(calendarServiceProvider)
            .save(target: target, draft: draft, applyToSimilar: applyToSimilar),
        AppLocalizations.of(context).eventSaved,
      );
    case EditorDeleteRequested():
      return deleteInstance(
        context,
        ref,
        item,
        wholeSeries: contactForm == ContactEventKind.birthday,
      );
  }
}

/// Le formulaire court de [item] s'il est dans l'agenda d'un proche où
/// l'on écrit, sinon `null` (éditeur complet).
ContactEventKind? _contactForm(AgendaItem item, List<UserCalendar> calendars) {
  final calendar = calendars.where((c) => c.id == item.calendarId).firstOrNull;
  if (calendar == null || !calendar.isContact || !calendar.isWritable) {
    return null;
  }
  return contactFormFor(item);
}

/// Supprime [item] (après la question de portée pour une série, sauf
/// [wholeSeries]) ; vrai si c'est fait.
Future<bool> deleteInstance(
  BuildContext context,
  WidgetRef ref,
  AgendaItem item, {
  bool wholeSeries = false,
}) async {
  final target = wholeSeries
      ? EditTarget.series(item)
      : await askScope(context, item, ScopeQuestion.delete);
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

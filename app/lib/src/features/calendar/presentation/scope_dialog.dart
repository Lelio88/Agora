/// Question « cette occurrence ou toute la série ? », posée avant de
/// modifier, déplacer ou supprimer une instance d'un rdv répété.
///
/// [allowOccurrence] à faux ne laisse que « toute la série », avec
/// l'explication : c'est le cas d'un changement d'agenda, qu'une occurrence
/// seule ne peut pas faire (elle vit toujours dans l'agenda de sa série).
library;

import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

enum ScopeQuestion { edit, move, delete }

Future<EditTarget?> showScopeDialog(
  BuildContext context, {
  required AgendaItem item,
  required ScopeQuestion question,
  bool allowOccurrence = true,
}) => showDialog<EditTarget>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final body = switch (question) {
      ScopeQuestion.edit => l10n.scopeEditBody,
      ScopeQuestion.move => l10n.scopeMoveBody,
      ScopeQuestion.delete => l10n.scopeDeleteBody,
    };
    return AlertDialog(
      title: Text(l10n.scopeTitle),
      content: Text(allowOccurrence ? body : l10n.scopeCalendarMoveNote),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        if (allowOccurrence)
          TextButton(
            key: CalendarKeys.scopeOccurrence,
            onPressed: () =>
                Navigator.of(context).pop(EditTarget.occurrence(item)),
            child: Text(l10n.scopeThisOccurrence),
          ),
        FilledButton(
          key: CalendarKeys.scopeSeries,
          onPressed: () => Navigator.of(context).pop(EditTarget.series(item)),
          child: Text(l10n.scopeWholeSeries),
        ),
      ],
    );
  },
);

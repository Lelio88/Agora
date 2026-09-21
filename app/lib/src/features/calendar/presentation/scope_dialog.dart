/// Question « cette occurrence ou toute la série ? », posée avant de
/// modifier ou supprimer une instance d'un rdv répété.
library;

import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

Future<EditTarget?> showScopeDialog(
  BuildContext context, {
  required AgendaItem item,
  required bool isDeletion,
}) => showDialog<EditTarget>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.scopeTitle),
      content: Text(isDeletion ? l10n.scopeDeleteBody : l10n.scopeEditBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
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

/// Fiche d'un rdv importé par lien iCal : en lecture seule (il se modifie
/// dans l'agenda d'origine, la synchro écraserait tout changement), sauf ce
/// que les groupes en voient — réglage que la synchro ne touche jamais.
///
/// Comme les éditeurs, la fiche ne parle pas au serveur : elle renvoie le
/// nouveau réglage ([VisibilityChoice]), ou `null` si l'on ferme sans
/// enregistrer.
library;

import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/visibility_field.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Réglage choisi ; [value] `null` : selon l'agenda et le groupe.
final class VisibilityChoice {
  const VisibilityChoice(this.value);
  final EventVisibility? value;
}

Future<VisibilityChoice?> showImportedEventSheet(
  BuildContext context, {
  required AgendaItem item,
  required UserCalendar calendar,
}) => showModalBottomSheet<VisibilityChoice>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ImportedEventSheet(item: item, calendar: calendar),
);

class _ImportedEventSheet extends StatefulWidget {
  const _ImportedEventSheet({required this.item, required this.calendar});

  final AgendaItem item;
  final UserCalendar calendar;

  @override
  State<_ImportedEventSheet> createState() => _ImportedEventSheetState();
}

class _ImportedEventSheetState extends State<_ImportedEventSheet> {
  late EventVisibility? _visibility = widget.item.visibility;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = widget.item;
    final changed = _visibility != item.visibility;
    return SafeArea(
      child: SingleChildScrollView(
        key: CalendarKeys.importedEventSheet,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _Line(
              icon: Icons.schedule,
              text: eventWhenLabel(
                item,
                Localizations.localeOf(context).toString(),
              ),
            ),
            if (item.location case final location?)
              _Line(icon: Icons.place_outlined, text: location),
            _Line(
              icon: Icons.circle,
              iconColor: colorFromHex(
                widget.calendar.colorHex,
                theme.colorScheme.primary,
              ),
              text: widget.calendar.name,
            ),
            if (item.description case final description?) ...[
              const SizedBox(height: 8),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            Text(l10n.importedEventReadOnly, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            VisibilityField(
              key: CalendarKeys.importedEventVisibility,
              value: _visibility,
              onChanged: (value) => setState(() => _visibility = value),
            ),
            if (item.kind == InstanceKind.seriesOccurrence)
              Text(
                l10n.importedEventSeriesNote,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: CalendarKeys.importedEventSave,
              onPressed: changed
                  ? () =>
                        Navigator.of(context).pop(VisibilityChoice(_visibility))
                  : null,
              child: Text(l10n.saveButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Créneau d'une instance, dans la langue [locale] : une date (ou deux, du
/// premier au dernier jour inclus) pour une journée entière, date et heures
/// sinon.
String eventWhenLabel(AgendaItem item, String locale) {
  final date = DateFormat.yMMMEd(locale);
  final time = DateFormat.Hm(locale);
  if (item.isAllDay) {
    // Dernier jour inclus, par le calendrier et non par soustraction de
    // 24 h : la nuit d'un changement d'heure n'en fait pas 24.
    final end = item.localEnd;
    final last = DateTime(end.year, end.month, end.day - 1);
    final start = item.localStart;
    final sameDay =
        last.year == start.year &&
        last.month == start.month &&
        last.day == start.day;
    return sameDay
        ? date.format(start)
        : '${date.format(start)} – ${date.format(last)}';
  }
  return '${date.format(item.localStart)} · '
      '${time.format(item.localStart)}–${time.format(item.localEnd)}';
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

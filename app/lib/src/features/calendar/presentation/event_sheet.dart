/// Fiche d'un rdv de mon agenda, ouverte d'un appui sur sa tuile : on le
/// lit (quand, où, répétition, agenda, ce qu'en voient les groupes), on s'y
/// rend, et on choisit de le modifier ou de le supprimer.
///
/// Choix non évidents :
/// - un appui ne modifie plus rien : la fiche se lit d'abord, comme celle
///   d'un rdv de groupe ; l'éditeur n'arrive que par « Modifier » ;
/// - la fiche ne fait aucune action elle-même : elle rend le choix
///   ([EventSheetChoice]) à l'agenda, qui pose la question de portée et
///   appelle le service (`event_actions.dart`) ;
/// - un rdv de proche dit « Pour toi seul » au lieu d'un niveau de partage :
///   aucun groupe ne le voit.
library;

import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/event_when_label.dart';
import 'package:agora/src/features/calendar/presentation/visibility_field.dart';
import 'package:agora/src/features/directions/presentation/go_there_button.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

enum EventSheetChoice { edit, delete }

/// Ouvre la fiche de [item], rangé dans [calendar] ; rend le choix fait, ou
/// `null` si l'on referme la fiche. [readOnly] : ni Modifier ni Supprimer
/// (le planning importé d'un proche).
Future<EventSheetChoice?> showEventSheet(
  BuildContext context, {
  required AgendaItem item,
  required UserCalendar? calendar,
  bool readOnly = false,
}) => showModalBottomSheet<EventSheetChoice>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) =>
      _EventSheet(item: item, calendar: calendar, readOnly: readOnly),
);

class _EventSheet extends StatelessWidget {
  const _EventSheet({
    required this.item,
    required this.calendar,
    required this.readOnly,
  });

  final AgendaItem item;
  final UserCalendar? calendar;
  final bool readOnly;

  String _repeatLabel(AppLocalizations l10n) {
    final rrule = item.rrule;
    final rule = rrule == null ? null : RecurrenceRule.parse(rrule);
    return switch (rule?.frequency) {
      null => l10n.repeatAdvanced,
      Frequency.daily => l10n.repeatDaily,
      Frequency.weekly => l10n.repeatWeekly,
      Frequency.monthly => l10n.repeatMonthly,
      Frequency.yearly => l10n.repeatYearly,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final text = Theme.of(context).textTheme;
    final owner = calendar;
    final location = item.location?.trim() ?? '';
    final description = item.description?.trim() ?? '';
    final color = colorFromHex(
      owner?.colorHex,
      Theme.of(context).colorScheme.primary,
    );
    Widget line(IconData icon, String value) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(value),
    );
    return SafeArea(
      child: SingleChildScrollView(
        key: CalendarKeys.eventSheet,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.title, style: text.titleLarge),
            const SizedBox(height: 8),
            line(Icons.schedule, eventWhenLabel(item, locale)),
            if (item.isRecurring) line(Icons.repeat, _repeatLabel(l10n)),
            if (owner != null)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Padding(
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(radius: 8, backgroundColor: color),
                ),
                title: Text(owner.name),
                subtitle: Text(
                  owner.isContact
                      ? l10n.contactCalendarSubtitle
                      : l10n.calendarVisibilitySummary(
                          visibilityLabel(
                            item.visibility ?? owner.visibility,
                            l10n,
                          ),
                        ),
                ),
              ),
            if (location.isNotEmpty) ...[
              line(Icons.place_outlined, location),
              GoThereButton(
                location: location,
                start: item.localStart,
                isAllDay: item.isAllDay,
              ),
            ],
            if (description.isNotEmpty) line(Icons.notes, description),
            const SizedBox(height: 16),
            if (!readOnly)
              Row(
                children: [
                  TextButton.icon(
                    key: CalendarKeys.delete,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.deleteEventButton),
                    onPressed: () =>
                        Navigator.of(context).pop(EventSheetChoice.delete),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: CalendarKeys.eventEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.eventEditButton),
                    onPressed: () =>
                        Navigator.of(context).pop(EventSheetChoice.edit),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

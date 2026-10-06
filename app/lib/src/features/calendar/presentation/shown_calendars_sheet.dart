/// « Agendas affichés » (bouton de la barre d'agenda) : une case par agenda
/// — les miens, ceux de mes proches, ceux de mes groupes — pour le montrer
/// ou le masquer dans ma vue.
///
/// Choix non évidents :
/// - c'est de l'**affichage**, pas du partage : la case ne change rien pour
///   les groupes, et la feuille le dit ;
/// - un groupe s'affiche sous son nom actuel, pas celui de son agenda, figé
///   à sa création ;
/// - la feuille suit la liste des agendas : une case cochée se met à jour
///   dès que le serveur a répondu.
library;

import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/common_widgets/section_title.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/calendars_actions.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ouvre la feuille des agendas affichés.
Future<void> showShownCalendarsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ShownCalendarsSheet(),
    );

class _ShownCalendarsSheet extends ConsumerWidget {
  const _ShownCalendarsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(calendarsProvider).value ?? const <UserCalendar>[];
    final groupNames = <String, String>{
      for (final group
          in ref.watch(myGroupsProvider).value ?? const <MyGroup>[])
        group.id: group.name,
    };
    final sections = [
      (
        l10n.calendarsTitle,
        [
          for (final c in all)
            if (c.isPersonal && !c.isContact) c,
        ],
      ),
      (
        l10n.contactCalendarsTitle,
        [
          for (final c in all)
            if (c.isContact) c,
        ],
      ),
      (
        l10n.groupsTitle,
        [
          for (final c in all)
            if (!c.isPersonal) c,
        ],
      ),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        key: CalendarKeys.shownCalendarsSheet,
        controller: scroll,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            title: Text(
              l10n.shownCalendarsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(l10n.shownCalendarsHint),
          ),
          for (final (title, calendars) in sections)
            if (calendars.isNotEmpty) ...[
              SectionTitle(title),
              for (final calendar in calendars)
                _ShownTile(
                  calendar: calendar,
                  name: groupNames[calendar.groupId] ?? calendar.name,
                  onChanged: (shown) => runCalendarAction(
                    context,
                    () => ref
                        .read(calendarsServiceProvider)
                        .setHidden(calendar.id, hidden: !shown),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _ShownTile extends StatelessWidget {
  const _ShownTile({
    required this.calendar,
    required this.name,
    required this.onChanged,
  });

  final UserCalendar calendar;
  final String name;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(
      calendar.colorHex,
      Theme.of(context).colorScheme.primary,
    );
    return CheckboxListTile(
      key: CalendarKeys.calendarShown(calendar.id),
      value: !calendar.hidden,
      activeColor: color,
      secondary: calendar.isPersonal
          ? CircleAvatar(radius: 8, backgroundColor: color)
          : Icon(Icons.groups_outlined, color: color),
      title: Text(name),
      onChanged: (value) => onChanged(value ?? true),
    );
  }
}

/// « Mes agendas » (onglet Moi) : mes agendas à moi, leur couleur et ce
/// qu'en voient les groupes ; créer, importer par lien iCal, modifier,
/// relancer la synchro, supprimer.
///
/// Choix non évidents :
/// - l'écran gère, il n'affiche pas : montrer ou masquer un agenda dans sa
///   vue se fait depuis l'agenda (« Agendas affichés »), les proches vivent
///   dans l'onglet Social, les agendas de groupes avec leur groupe ;
/// - l'état de synchro d'un agenda importé arrive en temps réel (la table
///   des agendas est publiée) ; tirer la liste vers le bas la relit quand
///   même, pour le cas où le temps réel manque ;
/// - supprimer un agenda annonce d'abord combien de rdv partent avec lui ;
///   le dernier agenda natif n'offre pas de bouton de suppression (le
///   serveur le refuse de toute façon) ; un agenda de proche n'en tient
///   jamais lieu.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/calendars_actions.dart';
import 'package:agora/src/features/calendar/presentation/feed_sync_labels.dart';
import 'package:agora/src/features/calendar/presentation/visibility_field.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalendarsScreen extends ConsumerWidget {
  const CalendarsScreen({super.key});

  static Future<void> show(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const CalendarsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final calendars = ref.watch(calendarsProvider);
    return Scaffold(
      key: CalendarKeys.calendarsScreen,
      appBar: AppBar(title: Text(l10n.calendarsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: CalendarKeys.newCalendar,
        icon: const Icon(Icons.add),
        label: Text(l10n.newCalendarButton),
        onPressed: () => createCalendar(context, ref),
      ),
      body: AsyncValueWidget<List<UserCalendar>>(
        value: calendars,
        data: (all) {
          final personal = all
              .where((c) => c.isPersonal && !c.isContact)
              .toList();
          final nativeCount = personal
              .where((c) => c.kind == CalendarKind.native)
              .length;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(calendarsProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final calendar in personal)
                  _CalendarTile(
                    calendar: calendar,
                    onTap: () => editCalendar(
                      context,
                      ref,
                      calendar,
                      canDelete:
                          calendar.kind != CalendarKind.native ||
                          nativeCount > 1,
                    ),
                  ),
                const Divider(),
                ListTile(
                  key: CalendarKeys.importCalendar,
                  leading: const Icon(Icons.link),
                  title: Text(l10n.importCalendarTitle),
                  subtitle: Text(l10n.importCalendarHint),
                  onTap: () => importCalendar(context, ref),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({required this.calendar, required this.onTap});

  final UserCalendar calendar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = colorFromHex(
      calendar.colorHex,
      Theme.of(context).colorScheme.primary,
    );
    final visibility = Text(
      l10n.calendarVisibilitySummary(
        visibilityLabel(calendar.visibility, l10n),
      ),
    );
    return ListTile(
      key: CalendarKeys.calendarTile(calendar.id),
      leading: CircleAvatar(radius: 10, backgroundColor: color),
      title: Text(calendar.name),
      isThreeLine: calendar.isImported,
      subtitle: calendar.isImported
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                visibility,
                _SyncStatus(calendar: calendar),
              ],
            )
          : visibility,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Ligne d'état de la synchro d'un agenda importé ; en couleur d'erreur si
/// la dernière relecture a échoué.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.calendar});

  final UserCalendar calendar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final failed = calendar.syncError != null;
    return Row(
      children: [
        Icon(
          failed ? Icons.sync_problem : Icons.sync,
          size: 14,
          color: failed ? Theme.of(context).colorScheme.error : null,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            syncStatusLabel(calendar, l10n, locale),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: failed
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
        ),
      ],
    );
  }
}

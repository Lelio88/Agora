/// « Mes agendas » : les agendas personnels, leur couleur et ce qu'en voient
/// les groupes ; une case pour les montrer ou les masquer dans sa propre
/// vue ; créer, importer par lien iCal, modifier, relancer la synchro,
/// supprimer. Puis les agendas de mes groupes (leurs rdv), à montrer ou
/// masquer de la même façon ; un appui ouvre le groupe.
///
/// Choix non évidents :
/// - l'état de synchro d'un agenda importé arrive en temps réel (la table
///   des agendas est publiée) ; tirer la liste vers le bas la relit quand
///   même, pour le cas où le temps réel manque ;
/// - la case ne touche que l'affichage de l'utilisateur (préférence dans
///   le compte), jamais ce que voient les groupes ;
/// - supprimer un agenda annonce d'abord combien de rdv partent avec lui ;
///   le dernier agenda natif n'offre pas de bouton de suppression (le
///   serveur le refuse de toute façon).
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/presentation/calendar_editor_screen.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/feed_sync_labels.dart';
import 'package:agora/src/features/calendar/presentation/import_calendar_screen.dart';
import 'package:agora/src/features/calendar/presentation/visibility_field.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        onPressed: () => _create(context, ref),
      ),
      body: AsyncValueWidget<List<UserCalendar>>(
        value: calendars,
        data: (all) {
          final personal = all.where((c) => c.isPersonal).toList();
          final ofGroups = all.where((c) => !c.isPersonal).toList();
          // Le nom du groupe plutôt que celui de son agenda, figé à sa
          // création : un groupe renommé garde sinon son ancien nom ici.
          final groupNames = <String, String>{
            for (final group
                in ref.watch(myGroupsProvider).value ?? const <MyGroup>[])
              group.id: group.name,
          };
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
                    onTap: () => _edit(
                      context,
                      ref,
                      calendar,
                      canDelete:
                          calendar.kind != CalendarKind.native ||
                          nativeCount > 1,
                    ),
                    onShownChanged: (shown) => _run(
                      context,
                      () => ref
                          .read(calendarsServiceProvider)
                          .setHidden(calendar.id, hidden: !shown),
                    ),
                  ),
                if (ofGroups.isNotEmpty) ...[
                  ListTile(
                    key: CalendarKeys.groupCalendarsHeader,
                    title: Text(
                      l10n.groupCalendarsTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final calendar in ofGroups)
                    _GroupCalendarTile(
                      calendar: calendar,
                      name: groupNames[calendar.groupId] ?? calendar.name,
                      onTap: () => context.pushNamed(
                        AppRoute.group.name,
                        pathParameters: {'groupId': calendar.groupId!},
                      ),
                      onShownChanged: (shown) => _run(
                        context,
                        () => ref
                            .read(calendarsServiceProvider)
                            .setHidden(calendar.id, hidden: !shown),
                      ),
                    ),
                ],
                const Divider(),
                ListTile(
                  key: CalendarKeys.importCalendar,
                  leading: const Icon(Icons.link),
                  title: Text(l10n.importCalendarTitle),
                  subtitle: Text(l10n.importCalendarHint),
                  onTap: () => _import(context, ref),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final draft = await ImportCalendarScreen.show(context);
    if (draft == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(calendarsServiceProvider).import(draft),
      success: AppLocalizations.of(context).calendarImported,
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await CalendarEditorScreen.show(context);
    if (result is! CalendarEditorSaved || !context.mounted) return;
    await _run(
      context,
      () => ref.read(calendarsServiceProvider).create(result.draft),
      success: AppLocalizations.of(context).calendarSaved,
    );
  }

  Future<void> _edit(
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
    if (result == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final service = ref.read(calendarsServiceProvider);
    switch (result) {
      case CalendarEditorSaved(:final draft):
        await _run(
          context,
          () => service.update(calendar.id, draft),
          success: l10n.calendarSaved,
        );
      case CalendarEditorSyncRequested():
        await _run(
          context,
          () => service.syncNow(calendar.id),
          success: l10n.syncRequested,
        );
      case CalendarEditorDeleteRequested():
        final int count;
        try {
          count = await service.countEvents(calendar.id);
        } on Exception catch (error) {
          if (context.mounted) _showError(context, error);
          return;
        }
        if (!context.mounted) return;
        final confirmed = await _confirmDelete(context, calendar, count);
        if (!confirmed || !context.mounted) return;
        await _run(
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

  /// Lance [action] ; affiche [success] ou le message de l'erreur.
  Future<void> _run(
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
    } on Exception catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, Exception error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messageForError(error, AppLocalizations.of(context))),
      ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({
    required this.calendar,
    required this.onTap,
    required this.onShownChanged,
  });

  final UserCalendar calendar;
  final VoidCallback onTap;
  final ValueChanged<bool> onShownChanged;

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
      trailing: Checkbox(
        key: CalendarKeys.calendarShown(calendar.id),
        value: !calendar.hidden,
        activeColor: color,
        semanticLabel: l10n.calendarShownTooltip,
        onChanged: (value) => onShownChanged(value ?? true),
      ),
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

/// Agenda d'un groupe : ses rdv se montrent ou se masquent dans ma vue.
class _GroupCalendarTile extends StatelessWidget {
  const _GroupCalendarTile({
    required this.calendar,
    required this.name,
    required this.onTap,
    required this.onShownChanged,
  });

  final UserCalendar calendar;
  final String name;
  final VoidCallback onTap;
  final ValueChanged<bool> onShownChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = colorFromHex(
      calendar.colorHex,
      Theme.of(context).colorScheme.secondary,
    );
    return ListTile(
      key: CalendarKeys.calendarTile(calendar.id),
      leading: Icon(Icons.groups_outlined, color: color),
      title: Text(name),
      trailing: Checkbox(
        key: CalendarKeys.calendarShown(calendar.id),
        value: !calendar.hidden,
        activeColor: color,
        semanticLabel: l10n.calendarShownTooltip,
        onChanged: (value) => onShownChanged(value ?? true),
      ),
      onTap: onTap,
    );
  }
}

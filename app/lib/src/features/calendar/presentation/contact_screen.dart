/// Page d'un proche (onglet Social → un proche) : ce qui est noté pour lui
/// en ce moment, des raccourcis pour noter vite son anniversaire, ses
/// horaires de travail, un congé ou importer son planning, et ses rdv des
/// prochains jours.
///
/// Choix non évidents :
/// - un raccourci ouvre le **formulaire court** de sa sorte de rdv
///   (`ContactEventEditor`) : un anniversaire ne demande qu'une date, des
///   horaires de travail que les jours et les heures. « Ajouter » garde
///   l'éditeur complet, pour tout le reste ;
/// - les repos ne se notent pas : un jour sans horaires de travail en est
///   un, et « en ce moment » le dit ; un congé l'emporte sur les horaires
///   des jours qu'il couvre, ici comme dans la liste
///   (`withoutWorkOnDaysOff`) ;
/// - « en ce moment » dit ce qui est noté (et le repos qui s'en déduit),
///   pas si le proche est libre ;
/// - le planning importé d'un proche est un agenda à part (lecture seule) :
///   « Importer son planning » le crée à côté de celui-ci, et la page d'un
///   agenda importé n'offre ni raccourci ni ajout.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/application/upcoming_providers.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/contact_agenda.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/calendars_actions.dart';
import 'package:agora/src/features/calendar/presentation/contact_event_editor.dart';
import 'package:agora/src/features/calendar/presentation/contact_member_section.dart';
import 'package:agora/src/features/calendar/presentation/event_actions.dart';
import 'package:agora/src/features/calendar/presentation/event_editor_screen.dart';
import 'package:agora/src/features/calendar/presentation/event_when_label.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ContactScreen extends ConsumerWidget {
  const ContactScreen({required this.calendarId, super.key});

  final String calendarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendars = ref.watch(calendarsProvider);
    return AsyncValueWidget<List<UserCalendar>>(
      value: calendars,
      data: (all) {
        final calendar = all.where((c) => c.id == calendarId).firstOrNull;
        // Supprimé (ici ou ailleurs) : la page n'a plus rien à montrer.
        if (calendar == null) {
          return Scaffold(key: CalendarKeys.contactScreen, appBar: AppBar());
        }
        return _ContactPage(calendar: calendar);
      },
    );
  }
}

class _ContactPage extends ConsumerWidget {
  const _ContactPage({required this.calendar});

  final UserCalendar calendar;

  List<UserCalendar> _writable(WidgetRef ref) => [
    for (final c in ref.read(calendarsProvider).value ?? const <UserCalendar>[])
      if (c.isWritable) c,
  ];

  String _timezone(WidgetRef ref) =>
      ref.read(currentProfileProvider).value?.timezone ?? 'Europe/Paris';

  /// « Ajouter » : l'éditeur complet, pour ce qui n'a pas de raccourci.
  Future<void> _addEvent(BuildContext context, WidgetRef ref) async {
    final result = await EventEditorScreen.show(
      context,
      calendarId: calendar.id,
      timezone: _timezone(ref),
      calendars: _writable(ref),
    );
    if (!context.mounted) return;
    await _create(context, ref, result);
  }

  /// Un raccourci : le formulaire court de [kind].
  Future<void> _addShortcut(
    BuildContext context,
    WidgetRef ref,
    ContactEventKind kind, {
    required String title,
  }) async {
    final result = await ContactEventEditor.show(
      context,
      kind: kind,
      calendarId: calendar.id,
      timezone: _timezone(ref),
      initialTitle: title,
    );
    if (!context.mounted) return;
    await _create(context, ref, result);
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    EditorResult? result,
  ) async {
    if (result is! EditorSaved || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(calendarServiceProvider).create(result.draft),
      AppLocalizations.of(context).eventSaved,
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final deleted = await editCalendar(context, ref, calendar, canDelete: true);
    if (deleted && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(contactAgendaProvider(calendar.id));
    final canWrite = calendar.isWritable;
    return Scaffold(
      key: CalendarKeys.contactScreen,
      appBar: AppBar(
        title: Text(calendar.name),
        actions: [
          IconButton(
            key: CalendarKeys.contactEdit,
            tooltip: l10n.contactEditTooltip,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, ref),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              key: CalendarKeys.contactAddEvent,
              icon: const Icon(Icons.add),
              label: Text(l10n.contactAddEventButton),
              onPressed: () => _addEvent(context, ref),
            )
          : null,
      body: AsyncValueWidget<List<AgendaItem>>(
        value: items.whenData(withoutWorkOnDaysOff),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            _PrivacyNote(calendar: calendar),
            ContactMemberLink(calendar: calendar),
            _NowSection(items: list),
            if (canWrite)
              _Shortcuts(
                onBirthday: () => _addShortcut(
                  context,
                  ref,
                  ContactEventKind.birthday,
                  title: l10n.birthdayEventTitle(calendar.name),
                ),
                onWorkHours: () => _addShortcut(
                  context,
                  ref,
                  ContactEventKind.workHours,
                  title: l10n.workEventTitle,
                ),
                onDayOff: () => _addShortcut(
                  context,
                  ref,
                  ContactEventKind.dayOff,
                  title: l10n.dayOffEventTitle,
                ),
                onImport: () => importCalendar(
                  context,
                  ref,
                  contact: true,
                  name: l10n.contactImportedName(calendar.name),
                ),
              ),
            _UpcomingList(
              items: list,
              onTap: canWrite
                  ? (item) => editInstance(
                      context,
                      ref,
                      item,
                      calendars: _writable(ref),
                    )
                  : null,
            ),
            if (calendar.contactUserId case final userId?)
              ContactSharedAgenda(userId: userId),
          ],
        ),
      ),
    );
  }
}

/// En tête : la couleur du proche, et le rappel que tout reste à soi.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.calendar});

  final UserCalendar calendar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = colorFromHex(
      calendar.colorHex,
      Theme.of(context).colorScheme.primary,
    );
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Text(
          calendar.name.characters.firstOrNull?.toUpperCase() ?? '',
          style: TextStyle(color: readableOn(color)),
        ),
      ),
      title: Text(
        calendar.isImported
            ? l10n.contactImportedSubtitle
            : l10n.contactCalendarHint,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.lock_outline, size: 18),
    );
  }
}

/// Ce qui est noté maintenant, et ce qui vient ensuite.
class _NowSection extends StatelessWidget {
  const _NowSection({required this.items});

  final List<AgendaItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.Hm(locale);
    final moment = contactMoment(items, now: DateTime.now());
    final lines = [
      if (moment.isRestDay) l10n.contactRestToday,
      for (final item in moment.current)
        item.isAllDay
            ? item.title
            : l10n.contactUntil(item.title, time.format(item.localEnd)),
    ];
    final now = lines.isEmpty ? l10n.contactNothingNow : lines.join('\n');
    final next = moment.next;
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: Text(l10n.contactNowTitle),
      subtitle: Text(
        next == null
            ? now
            : '$now\n${l10n.contactNext(next.title, eventWhenLabel(next, locale))}',
      ),
    );
  }
}

/// Les raccourcis : un appui ouvre le formulaire court prérempli.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({
    required this.onBirthday,
    required this.onWorkHours,
    required this.onDayOff,
    required this.onImport,
  });

  final VoidCallback onBirthday;
  final VoidCallback onWorkHours;
  final VoidCallback onDayOff;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget chip(Key key, IconData icon, String label, VoidCallback onPressed) =>
        ActionChip(
          key: key,
          avatar: Icon(icon, size: 18),
          label: Text(label),
          onPressed: onPressed,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.contactShortcutsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(
                CalendarKeys.contactBirthday,
                Icons.cake_outlined,
                l10n.shortcutBirthday,
                onBirthday,
              ),
              chip(
                CalendarKeys.contactWorkHours,
                Icons.work_outline,
                l10n.shortcutWorkHours,
                onWorkHours,
              ),
              chip(
                CalendarKeys.contactDayOff,
                Icons.beach_access_outlined,
                l10n.shortcutDayOff,
                onDayOff,
              ),
              chip(
                CalendarKeys.contactImport,
                Icons.link,
                l10n.shortcutImport,
                onImport,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Les rdv des prochains jours, dans l'ordre.
class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.items, required this.onTap});

  final List<AgendaItem> items;

  /// `null` pour un agenda en lecture seule (importé).
  final void Function(AgendaItem item)? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final sorted = [...items]
      ..sort((a, b) => a.localStart.compareTo(b.localStart));
    final tap = onTap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            l10n.contactUpcomingTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.contactNothingUpcoming),
          ),
        for (final item in sorted)
          ListTile(
            key: CalendarKeys.contactEvent(item.instanceKey),
            title: Text(item.title),
            subtitle: Text(eventWhenLabel(item, locale)),
            trailing: item.isRecurring
                ? const Icon(Icons.repeat, size: 18)
                : null,
            onTap: tap == null ? null : () => tap(item),
          ),
      ],
    );
  }
}

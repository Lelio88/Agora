/// Un rdv préparé dans une autre app (Arpente), ouvert par la route
/// `/event?…` : l'éditeur de rdv habituel, prérempli, où la personne choisit
/// son agenda ou celui d'un de ses groupes — le rdv est alors proposé au
/// groupe — et vérifie tout avant d'enregistrer.
///
/// Choix non évidents :
/// - le lien est lu par `domain/event_link.dart` ; un lien illisible ouvre
///   un écran qui le dit, jamais un éditeur à moitié rempli ;
/// - le groupe du lien (`groupe`, le jumeau Agora du groupe de l'autre app)
///   n'est présélectionné que si la personne en est déjà membre
///   (`invite_preview`) : sinon son agenda l'est, et on lui propose de
///   rejoindre le groupe d'abord. Le code n'est ni gardé ni recopié ;
/// - un aperçu d'invitation en échec (jumelage défait depuis) se tait : le
///   rdv reste à ranger dans son agenda ;
/// - l'attente ne s'affiche qu'au premier chargement : la liste des agendas
///   se relit à chaque changement en temps réel, et remplacer l'éditeur par
///   l'attente jetterait la saisie ;
/// - les agendas proposés : les miens qui s'écrivent (sans ceux des proches,
///   qui ne sont pas pour moi) et ceux de mes groupes.
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/application/event_link_providers.dart';
import 'package:agora/src/features/calendar/domain/event_link.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/event_actions.dart';
import 'package:agora/src/features/calendar/presentation/event_editor_screen.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EventLinkPage extends ConsumerStatefulWidget {
  const EventLinkPage({required this.params, super.key});

  /// Les paramètres du lien, tels que reçus.
  final Map<String, String> params;

  @override
  ConsumerState<EventLinkPage> createState() => _EventLinkPageState();
}

class _EventLinkPageState extends ConsumerState<EventLinkPage> {
  late final EventLink? _link = parseEventLink(widget.params);

  @override
  void initState() {
    super.initState();
    ref.read(pendingEventLinkProvider).location = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final link = _link;
    if (link == null) {
      return _Message(
        key: CalendarKeys.eventLinkInvalid,
        text: l10n.eventLinkInvalid,
      );
    }
    final calendars = ref.watch(calendarsProvider);
    final AsyncValue<InvitePreview?> preview = switch (link.groupCode) {
      final code? => ref.watch(invitePreviewProvider(code)),
      null => const AsyncData<InvitePreview?>(null),
    };
    // Attendre le premier chargement seulement : une relecture (temps réel)
    // garde sa valeur, et remplacer l'éditeur jetterait ce qui a été saisi.
    if (!calendars.hasValue && !calendars.hasError ||
        !preview.hasValue && !preview.hasError) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (calendars.error case final error? when !calendars.hasValue) {
      return _Message(text: messageForError(error, l10n));
    }
    final options = _destinations(calendars.value ?? const []);
    final personal = options.where((c) => c.isPersonal).firstOrNull;
    if (personal == null) return _Message(text: l10n.errorCalendarNotFound);
    // Un aperçu en échec se tait : le rdv reste à ranger dans son agenda.
    final group = preview.hasError ? null : preview.value;
    final groupCalendar = group != null && group.isMember
        ? options.where((c) => c.groupId == group.groupId).firstOrNull
        : null;
    final timezone =
        ref.watch(currentProfileProvider).value?.timezone ?? 'Europe/Paris';
    return EventEditorScreen(
      calendarId: (groupCalendar ?? personal).id,
      timezone: timezone,
      calendars: options,
      initialStart: link.start,
      initialEnd: link.end,
      initialTitle: link.title,
      initialLocation: link.location,
      initialDescription: link.description,
      notice: _Notice(link: link, group: group),
      onResult: (result) async => switch (result) {
        EditorSaved(:final draft) => runAction(
          context,
          () => ref.read(calendarServiceProvider).create(draft),
          options.any((c) => c.id == draft.calendarId && !c.isPersonal)
              ? l10n.eventProposed
              : l10n.eventSaved,
        ),
        EditorDeleteRequested() => false,
      },
    );
  }

  /// Mes agendas qui s'écrivent, hors proches, puis ceux de mes groupes.
  static List<UserCalendar> _destinations(List<UserCalendar> calendars) => [
    for (final calendar in calendars)
      if (calendar.isWritable && !calendar.isContact) calendar,
    for (final calendar in calendars)
      if (calendar.groupId != null && calendar.kind == CalendarKind.native)
        calendar,
  ];
}

/// D'où vient le rdv, et, si la personne n'est pas encore dans le groupe
/// jumeau, de quoi le rejoindre.
class _Notice extends StatelessWidget {
  const _Notice({required this.link, required this.group});

  final EventLink link;
  final InvitePreview? group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = link.sender.displayName;
    final outsider = group != null && !group!.isMember ? group : null;
    final code = link.groupCode;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.eventLinkFrom(app)),
            if (outsider != null && code != null) ...[
              const SizedBox(height: 8),
              Text(l10n.eventLinkNotMember(outsider.name, app)),
              TextButton(
                key: CalendarKeys.eventLinkJoin,
                onPressed: () => context.goNamed(
                  AppRoute.join.name,
                  pathParameters: {'code': code},
                ),
                child: Text(l10n.eventLinkJoinButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    ),
  );
}

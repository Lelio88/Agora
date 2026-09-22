/// Écran d'agenda : vues jour, semaine, mois et planning (kalender), création
/// et modification des rdv, choix « cette occurrence / toute la série ». Un
/// rdv importé par lien iCal s'ouvre en lecture seule ; un rdv de groupe
/// ouvre sa fiche (réponses), et se montre estompé si j'ai répondu absent.
///
/// Choix non évidents :
/// - vues, barre et plage chargée viennent de `common_widgets/agenda_view.dart`,
///   partagé avec l'agenda d'un groupe ;
/// - les instances viennent d'`agendaProvider` et sont poussées dans le
///   contrôleur de kalender à chaque changement : kalender ne connaît pas le
///   dépôt, il n'affiche que ce qu'on lui donne ;
/// - kalender travaille dans le fuseau local de l'appareil, ce qui est celui
///   de l'affichage attendu.
library;

import 'package:agora/src/common_widgets/agenda_view.dart';
import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/agenda_event.dart';
import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/calendars_screen.dart';
import 'package:agora/src/features/calendar/presentation/event_actions.dart';
import 'package:agora/src/features/calendar/presentation/event_editor_screen.dart';
import 'package:agora/src/features/calendar/presentation/imported_event_sheet.dart';
import 'package:agora/src/features/calendar/presentation/scope_dialog.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kalender/kalender.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final _eventsController = DefaultEventsController();
  final _kalenderController = KalenderController();
  AgendaView _view = AgendaView.week;
  late final VisibleRangeFollower _follower;
  late AgendaRange _range;

  @override
  void initState() {
    super.initState();
    _follower = VisibleRangeFollower(
      _kalenderController,
      initialDate: DateTime.now(),
      onRangeChanged: (range) {
        if (mounted) setState(() => _range = _toAgendaRange(range));
      },
    );
    _range = _toAgendaRange(_follower.range);
  }

  @override
  void dispose() {
    _follower.dispose();
    _kalenderController.dispose();
    _eventsController.dispose();
    super.dispose();
  }

  static AgendaRange _toAgendaRange(LoadedRange range) =>
      AgendaRange(from: range.from, to: range.to);

  Future<void> _createEvent([DateTime? start]) async {
    final calendarId = await ref.read(defaultCalendarIdProvider.future);
    final timezone =
        ref.read(currentProfileProvider).value?.timezone ?? 'Europe/Paris';
    if (!mounted) return;
    final result = await EventEditorScreen.show(
      context,
      calendarId: calendarId,
      timezone: timezone,
      calendars: _writableCalendars,
      initialStart: start,
    );
    if (result is! EditorSaved || !mounted) return;
    await runAction(
      context,
      () => ref.read(calendarServiceProvider).create(result.draft),
      AppLocalizations.of(context).eventSaved,
    );
  }

  Future<void> _editEvent(AgendaItem item) =>
      editInstance(context, ref, item, calendars: _writableCalendars);

  /// Un rdv de groupe s'ouvre sur sa fiche (réponses, qui vient), par la
  /// même route que depuis l'agenda du groupe.
  void _openGroupEvent(String groupId, AgendaItem item) {
    context.pushNamed(
      AppRoute.groupEvent.name,
      pathParameters: {'groupId': groupId, 'eventId': item.eventId},
      queryParameters: {'start': item.start.toUtc().toIso8601String()},
    );
  }

  /// Un rdv importé ne se modifie pas ici : sa fiche ne règle que ce que
  /// les groupes en voient.
  Future<void> _showImportedEvent(
    AgendaItem item,
    UserCalendar calendar,
  ) async {
    final choice = await showImportedEventSheet(
      context,
      item: item,
      calendar: calendar,
    );
    if (choice == null || !mounted) return;
    await runAction(
      context,
      () => ref.read(calendarServiceProvider).setVisibility(item, choice.value),
      AppLocalizations.of(context).eventVisibilitySaved,
    );
  }

  /// Glisser-déposer ou étirement d'une tuile : kalender a déjà déplacé la
  /// tuile ; on enregistre, ou on la remet en place si l'utilisateur
  /// renonce ou si l'enregistrement échoue.
  Future<void> _moveEvent(KalenderEvent original, KalenderEvent moved) async {
    if (original is! AgendaEvent) return;
    final item = original.item;
    final (start, end) = item.isAllDay
        ? (_calendarDateUtc(moved.start), _calendarDateUtc(moved.end))
        : (moved.start.toUtc(), moved.end.toUtc());
    if (start == item.start && end == item.end) return;
    final draft = EventDraft.fromItem(item).copyWith(start: start, end: end);
    final target = await askScope(context, item, ScopeQuestion.move);
    if (!mounted) return;
    final saved =
        target != null &&
        await runAction(
          context,
          () => ref
              .read(calendarServiceProvider)
              .save(target: target, draft: draft),
          AppLocalizations.of(context).eventMoved,
        );
    if (!saved && mounted) _syncEvents(force: true);
  }

  /// Date de calendrier d'une journée entière déplacée : kalender la rend
  /// en minuit local, le stockage la veut en minuit UTC.
  static DateTime _calendarDateUtc(DateTime instant) {
    final local = instant.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  List<UserCalendar> get _writableCalendars => [
    for (final calendar
        in ref.read(calendarsProvider).value ?? const <UserCalendar>[])
      if (calendar.isWritable) calendar,
  ];

  List<AgendaItem>? _syncedItems;
  List<UserCalendar>? _syncedCalendars;

  /// Pousse les instances dans kalender, seulement si elles ont changé :
  /// une reconstruction en plein glisser-déposer ne doit pas remettre la
  /// tuile à sa place. [force] le fait exprès (déplacement abandonné).
  void _syncEvents({bool force = false}) {
    final items = ref.read(visibleAgendaProvider(_range)).value;
    final calendars =
        ref.read(calendarsProvider).value ?? const <UserCalendar>[];
    if (items == null) return;
    if (!force &&
        identical(items, _syncedItems) &&
        identical(calendars, _syncedCalendars)) {
      return;
    }
    _syncedItems = items;
    _syncedCalendars = calendars;
    final byId = {for (final calendar in calendars) calendar.id: calendar};
    _eventsController.replaceEvents([
      for (final item in items)
        AgendaEvent(item, calendar: byId[item.calendarId]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final agenda = ref.watch(visibleAgendaProvider(_range));
    // Les agendas donnent couleurs et droits de déplacement aux tuiles.
    ref.watch(calendarsProvider);
    _syncEvents();
    return Scaffold(
      key: CalendarKeys.screen,
      floatingActionButton: FloatingActionButton(
        key: CalendarKeys.newEvent,
        // Les onglets de l'accueil coexistent : chaque bouton a son tag.
        heroTag: CalendarKeys.newEvent,
        tooltip: l10n.newEventTooltip,
        onPressed: _createEvent,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          AgendaToolbar(
            keys: CalendarKeys.toolbar,
            view: _view,
            onViewChanged: (view) => setState(() => _view = view),
            controller: _kalenderController,
            trailing: [
              IconButton(
                key: CalendarKeys.manageCalendars,
                tooltip: l10n.manageCalendarsTooltip,
                icon: const Icon(Icons.event_note_outlined),
                onPressed: () => CalendarsScreen.show(context),
              ),
            ],
          ),
          Expanded(
            child: AsyncValueWidget<List<AgendaItem>>(
              value: agenda,
              data: (_) => KalenderView(
                eventsController: _eventsController,
                kalenderController: _kalenderController,
                viewConfiguration: agendaViewConfiguration(context, _view),
                locale: Localizations.localeOf(context),
                callbacks: KalenderCallbacks(
                  onEventTapped: (event) {
                    if (event is! AgendaEvent) return;
                    final calendar = event.calendar;
                    if (calendar?.groupId case final groupId?) {
                      _openGroupEvent(groupId, event.item);
                    } else if (calendar != null && calendar.isImported) {
                      _showImportedEvent(event.item, calendar);
                    } else {
                      _editEvent(event.item);
                    }
                  },
                  onEventChanged: _moveEvent,
                  onTapped: _createEvent,
                ),
                // Les journées entières vivent dans l'en-tête : sans ses
                // propres tuiles, kalender les dessine sans titre.
                header: KalenderHeader(
                  multiDayTileComponents: _tileComponents,
                  interaction: _interaction,
                ),
                body: KalenderBody(
                  multiDayTileComponents: _tileComponents,
                  monthTileComponents: _tileComponents,
                  scheduleTileComponents: const ScheduleTileComponents(
                    tileBuilder: _buildTile,
                  ),
                  interaction: _interaction,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Déplacer et étirer les tuiles (chacune dit si elle le permet) ; pas de
/// création par glisser : un appui sur un créneau ouvre déjà l'éditeur.
final _interaction = KalenderInteraction(allowEventCreation: false);

const _tileComponents = TileComponents(tileBuilder: _buildTile);

Widget _buildTile(
  BuildContext context,
  KalenderEvent event,
  KalenderDateTimeRange tileRange,
) {
  final colors = Theme.of(context).colorScheme;
  final agendaEvent = event is AgendaEvent ? event : null;
  final item = agendaEvent?.item;
  final colorHex = agendaEvent?.calendar?.colorHex;
  final background = colorFromHex(colorHex, colors.primaryContainer);
  final foreground = colorHex == null
      ? colors.onPrimaryContainer
      : readableOn(background);
  // Un rdv de groupe auquel j'ai répondu absent reste visible, estompé et
  // barré : l'information n'est pas perdue, mais ne prend plus la place.
  final response = item?.myResponse;
  final declined = response == ResponseStatus.no;
  final responseIcon = switch (response) {
    ResponseStatus.yes => Icons.check_circle_outline,
    ResponseStatus.maybe => Icons.help_outline,
    _ => null,
  };
  return Opacity(
    opacity: declined ? 0.45 : 1,
    child: Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (item?.isRecurring ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.repeat, size: 12, color: foreground),
            ),
          if (responseIcon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(responseIcon, size: 12, color: foreground),
            ),
          Expanded(
            child: Text(
              item?.title ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                decoration: declined ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

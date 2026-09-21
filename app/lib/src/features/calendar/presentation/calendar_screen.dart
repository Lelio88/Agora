/// Écran d'agenda : vues jour, semaine, mois et planning (kalender), création
/// et modification des rdv, choix « cette occurrence / toute la série ».
///
/// Choix non évidents :
/// - la plage chargée suit la page visible, arrondie au mois entier avec un
///   mois de marge de chaque côté : changer de page ne recharge pas à chaque
///   jour, et la vue planning a toujours de quoi défiler ;
/// - les instances viennent d'`agendaProvider` et sont poussées dans le
///   contrôleur de kalender à chaque changement : kalender ne connaît pas le
///   dépôt, il n'affiche que ce qu'on lui donne ;
/// - kalender travaille dans le fuseau local de l'appareil, ce qui est celui
///   de l'affichage attendu.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/presentation/agenda_event.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/event_editor_screen.dart';
import 'package:agora/src/features/calendar/presentation/scope_dialog.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

enum AgendaView { day, week, month, schedule }

/// Au-delà, une plage « visible » n'est pas une page mais une vue entière.
const _maxVisible = Duration(days: 62);

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final _eventsController = DefaultEventsController();
  final _kalenderController = KalenderController();
  AgendaView _view = AgendaView.week;
  late AgendaRange _range = _rangeAround(DateTime.now());

  @override
  void initState() {
    super.initState();
    _kalenderController.visibleDateTimeRange.addListener(
      _onVisibleRangeChanged,
    );
  }

  @override
  void dispose() {
    _kalenderController.visibleDateTimeRange.removeListener(
      _onVisibleRangeChanged,
    );
    _kalenderController.dispose();
    _eventsController.dispose();
    super.dispose();
  }

  /// Mois entier autour de [date], plus un mois de chaque côté (UTC).
  static AgendaRange _rangeAround(DateTime date) {
    final local = date.toLocal();
    return AgendaRange(
      from: DateTime(local.year, local.month - 1).toUtc(),
      to: DateTime(local.year, local.month + 2).toUtc(),
    );
  }

  /// Quand la page visible sort de la plage chargée, on recharge autour du
  /// milieu de la page. Une plage visible plus longue que [_maxVisible] est
  /// ignorée : elle ne décrit pas ce qui est à l'écran (une vue continue
  /// publie sa plage totale), et la suivre rechargerait sans fin.
  void _onVisibleRangeChanged() {
    final visible = _kalenderController.visibleDateTimeRange.value;
    if (visible == null ||
        visible.end.difference(visible.start) > _maxVisible) {
      return;
    }
    final middle = visible.start.add(
      visible.end.difference(visible.start) ~/ 2,
    );
    final isInside =
        !middle.isBefore(_range.from) && middle.isBefore(_range.to);
    if (isInside) return;
    final needed = _rangeAround(middle);
    // kalender publie sa plage visible pendant sa propre construction : un
    // setState immédiat serait un « setState() called during build ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && needed != _range) setState(() => _range = needed);
    });
  }

  ViewConfiguration get _viewConfiguration => switch (_view) {
    AgendaView.day => MultiDayViewConfiguration.singleDay(
      initialTimeOfDay: const KalenderTime(hour: 7, minute: 0),
    ),
    AgendaView.week => MultiDayViewConfiguration.week(
      numberOfDays: MediaQuery.sizeOf(context).width < 600 ? 3 : 7,
      firstDayOfWeek: DateTime.monday,
      initialTimeOfDay: const KalenderTime(hour: 7, minute: 0),
    ),
    AgendaView.month => MonthViewConfiguration.singleMonth(
      firstDayOfWeek: DateTime.monday,
    ),
    // Paginée (un mois par page) : la variante continue publie sa plage
    // TOTALE comme plage visible, inexploitable pour savoir quoi charger.
    AgendaView.schedule => ScheduleViewConfiguration.paginated(),
  };

  Future<void> _createEvent([DateTime? start]) async {
    final calendarId = await ref.read(defaultCalendarIdProvider.future);
    final timezone =
        ref.read(currentProfileProvider).value?.timezone ?? 'Europe/Paris';
    if (!mounted) return;
    final result = await EventEditorScreen.show(
      context,
      calendarId: calendarId,
      timezone: timezone,
      initialStart: start,
    );
    if (result is! EditorSaved || !mounted) return;
    await _run(
      () => ref.read(calendarServiceProvider).create(result.draft),
      AppLocalizations.of(context).eventSaved,
    );
  }

  Future<void> _editEvent(AgendaItem item) async {
    final result = await EventEditorScreen.show(
      context,
      calendarId: item.calendarId,
      timezone: item.timezone,
      existing: item,
    );
    if (result == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (result) {
      case EditorSaved(:final draft):
        final target = await _askScope(item, isDeletion: false);
        if (target == null || !mounted) return;
        await _run(
          () => ref
              .read(calendarServiceProvider)
              .save(target: target, draft: draft),
          l10n.eventSaved,
        );
      case EditorDeleteRequested():
        final target = await _askScope(item, isDeletion: true);
        if (target == null || !mounted) return;
        await _run(
          () => ref.read(calendarServiceProvider).delete(target),
          l10n.eventDeleted,
        );
    }
  }

  /// Pour une instance de série, demande la portée ; sinon le rdv entier.
  Future<EditTarget?> _askScope(AgendaItem item, {required bool isDeletion}) {
    if (!item.isRecurring) return Future.value(EditTarget.series(item));
    return showScopeDialog(context, item: item, isDeletion: isDeletion);
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    }
  }

  void _syncEvents(List<AgendaItem> items) {
    _eventsController.replaceEvents(items.map(AgendaEvent.new).toList());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final agenda = ref.watch(agendaProvider(_range));
    ref.listen(agendaProvider(_range), (_, next) {
      if (next case AsyncData(:final value)) _syncEvents(value);
    });
    if (agenda case AsyncData(:final value)) _syncEvents(value);
    return Scaffold(
      key: CalendarKeys.screen,
      floatingActionButton: FloatingActionButton(
        key: CalendarKeys.newEvent,
        tooltip: l10n.newEventTooltip,
        onPressed: _createEvent,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _Toolbar(
            view: _view,
            onViewChanged: (view) => setState(() => _view = view),
            onToday: () => _kalenderController.animateToDate(DateTime.now()),
            onPrevious: _kalenderController.animateToPreviousPage,
            onNext: _kalenderController.animateToNextPage,
          ),
          Expanded(
            child: AsyncValueWidget<List<AgendaItem>>(
              value: agenda,
              data: (_) => KalenderView(
                eventsController: _eventsController,
                kalenderController: _kalenderController,
                viewConfiguration: _viewConfiguration,
                locale: Localizations.localeOf(context),
                callbacks: KalenderCallbacks(
                  onEventTapped: (event) {
                    if (event is AgendaEvent) _editEvent(event.item);
                  },
                  onTapped: _createEvent,
                ),
                // Les journées entières vivent dans l'en-tête : sans ses
                // propres tuiles, kalender les dessine sans titre.
                header: const KalenderHeader(
                  multiDayTileComponents: _tileComponents,
                ),
                body: KalenderBody(
                  multiDayTileComponents: _tileComponents,
                  monthTileComponents: _tileComponents,
                  scheduleTileComponents: const ScheduleTileComponents(
                    tileBuilder: _buildTile,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _tileComponents = TileComponents(tileBuilder: _buildTile);

Widget _buildTile(
  BuildContext context,
  KalenderEvent event,
  KalenderDateTimeRange tileRange,
) {
  final colors = Theme.of(context).colorScheme;
  final item = event is AgendaEvent ? event.item : null;
  return Container(
    margin: const EdgeInsets.all(1),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        if (item?.isRecurring ?? false)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.repeat,
              size: 12,
              color: colors.onPrimaryContainer,
            ),
          ),
        Expanded(
          child: Text(
            item?.title ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onPrimaryContainer, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.view,
    required this.onViewChanged,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
  });

  final AgendaView view;
  final ValueChanged<AgendaView> onViewChanged;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Défilable : sur un téléphone étroit, les quatre vues et les boutons
    // de navigation ne tiennent pas côte à côte.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.previousPeriod,
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          TextButton(
            key: CalendarKeys.today,
            onPressed: onToday,
            child: Text(l10n.todayButton),
          ),
          IconButton(
            tooltip: l10n.nextPeriod,
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          const SizedBox(width: 16),
          SegmentedButton<AgendaView>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AgendaView.day,
                label: Text(l10n.viewDay, key: CalendarKeys.viewDay),
              ),
              ButtonSegment(
                value: AgendaView.week,
                label: Text(l10n.viewWeek, key: CalendarKeys.viewWeek),
              ),
              ButtonSegment(
                value: AgendaView.month,
                label: Text(l10n.viewMonth, key: CalendarKeys.viewMonth),
              ),
              ButtonSegment(
                value: AgendaView.schedule,
                label: Text(l10n.viewSchedule, key: CalendarKeys.viewSchedule),
              ),
            ],
            selected: {view},
            onSelectionChanged: (selection) => onViewChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

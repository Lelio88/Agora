/// Briques communes aux vues d'agenda (agenda perso, agenda d'un groupe) :
/// les quatre vues de kalender, la barre qui les choisit, et le suivi de la
/// plage à charger.
///
/// Choix non évidents :
/// - la plage chargée suit la page visible, arrondie au mois entier avec un
///   mois de marge de chaque côté : changer de page ne recharge pas à chaque
///   jour, et la vue planning a toujours de quoi défiler ;
/// - une plage « visible » de plus de [maxVisibleRange] est ignorée : elle
///   ne décrit pas ce qui est à l'écran (une vue continue publie sa plage
///   totale) et la suivre rechargerait sans fin ;
/// - kalender publie sa plage visible pendant sa propre construction : le
///   changement de plage, comme le nom de la période dans la barre, est
///   différé à la fin de l'image ;
/// - la barre centre la navigation (`NavigationToolbar`, comme le titre
///   d'une AppBar : centrée si elle tient, décalée sinon, jamais par-dessus
///   les actions) ; sous [_wideToolbarWidth], les vues passent dessous, sur
///   toute la largeur, plutôt que de défiler hors de l'écran.
library;

import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kalender/kalender.dart';

enum AgendaView { day, week, month, schedule }

/// Clés d'une barre d'agenda, propres à l'écran qui la porte : l'agenda
/// perso reste monté sous l'écran d'un groupe (onglet de l'accueil), deux
/// barres coexistent alors et ne doivent pas partager leurs clés.
final class AgendaToolbarKeys {
  const AgendaToolbarKeys(this.scope);

  final String scope;

  ValueKey<String> get today => ValueKey('$scope.today');
  ValueKey<String> get day => ValueKey('$scope.viewDay');
  ValueKey<String> get week => ValueKey('$scope.viewWeek');
  ValueKey<String> get month => ValueKey('$scope.viewMonth');
  ValueKey<String> get schedule => ValueKey('$scope.viewSchedule');
  ValueKey<String> get period => ValueKey('$scope.period');
}

/// Au-delà, une plage « visible » n'est pas une page mais une vue entière.
const maxVisibleRange = Duration(days: 62);

/// Plage [from, to[ à charger, en UTC.
typedef LoadedRange = ({DateTime from, DateTime to});

/// Mois entier autour de [date], plus un mois de chaque côté (UTC).
LoadedRange monthsAround(DateTime date) {
  final local = date.toLocal();
  return (
    from: DateTime(local.year, local.month - 1).toUtc(),
    to: DateTime(local.year, local.month + 2).toUtc(),
  );
}

/// Configuration kalender de [view].
///
/// Sur un écran étroit, la semaine devient **trois jours glissants** à partir
/// d'aujourd'hui, qui avancent de trois en trois : `MultiDayViewConfiguration
/// .week(numberOfDays: 3)` raccourcit la page sans changer la pagination, si
/// bien qu'il montrait toujours lundi–mercredi et jamais jeudi–dimanche. La
/// variante `custom` pagine par trois jours depuis le début de sa plage, que
/// [_rollingRange] aligne sur aujourd'hui.
///
/// Toutes les vues se calent sur aujourd'hui quand on y arrive depuis une
/// plage qui le contient ([keepTodayInView]).
ViewConfiguration agendaViewConfiguration(
  BuildContext context,
  AgendaView view,
) => switch (view) {
  AgendaView.day => MultiDayViewConfiguration.singleDay(
    initialTimeOfDay: const KalenderTime(hour: 7, minute: 0),
    dateResolver: keepTodayInView,
  ),
  AgendaView.week when MediaQuery.sizeOf(context).width < 600 =>
    MultiDayViewConfiguration.custom(
      numberOfDays: _narrowDays,
      displayRange: _rollingRange(),
      initialTimeOfDay: const KalenderTime(hour: 7, minute: 0),
      dateResolver: keepTodayInView,
    ),
  AgendaView.week => MultiDayViewConfiguration.week(
    firstDayOfWeek: DateTime.monday,
    initialTimeOfDay: const KalenderTime(hour: 7, minute: 0),
    dateResolver: keepTodayInView,
  ),
  AgendaView.month => MonthViewConfiguration.singleMonth(
    firstDayOfWeek: DateTime.monday,
    dateResolver: keepTodayInView,
  ),
  // Paginée (un mois par page) : la variante continue publie sa plage
  // TOTALE comme plage visible, inexploitable pour savoir quoi charger.
  AgendaView.schedule => ScheduleViewConfiguration.paginated(
    dateResolver: keepTodayInView,
  ),
};

/// Jours de la semaine réduite d'un écran étroit.
const _narrowDays = 3;

/// Plage de la semaine réduite : deux ans de part et d'autre, comme la plage
/// par défaut de kalender, mais commencée un multiple de [_narrowDays] jours
/// avant aujourd'hui, pour qu'une page commence aujourd'hui. Recalculée à
/// chaque construction, elle reste identique dans la journée : kalender, qui
/// compare les plages, ne relance pas de transition. La première
/// reconstruction après minuit en relance une, voulue : [keepTodayInView]
/// recale alors la page sur le nouveau jour (ou garde la période consultée).
KalenderDateTimeRange _rollingRange() {
  final now = DateTime.now();
  const span = _narrowDays * 245; // ≈ 2 ans
  return KalenderDateTimeRange(
    start: DateTime(now.year, now.month, now.day - span),
    end: DateTime(now.year, now.month, now.day + span),
  );
}

/// Date d'arrivée sur une vue.
///
/// kalender reprend le début de la plage quittée : depuis la semaine, c'est
/// le lundi. Un jeudi 1er octobre, la semaine commence le 28 septembre, et le
/// mois ou le planning ouvrait septembre, sans les rdv du jour. Si la plage
/// quittée contient aujourd'hui, on s'y cale ; sinon (on regardait une autre
/// période), le choix par défaut de kalender s'applique.
FloatingDateTime keepTodayInView(ViewTransitionContext transition) {
  final range = transition.oldViewController.floatingVisibleRange.value;
  if (range != null && range.dates().any((date) => date.isToday())) {
    return FloatingDateTime.fromDateTime(DateTime.now()).startOfDay;
  }
  return kCarryFocusDate(transition);
}

/// Suit la page visible d'un [KalenderController] et annonce, par
/// [onRangeChanged], la plage à charger quand la page en sort.
final class VisibleRangeFollower {
  VisibleRangeFollower(
    this._controller, {
    required DateTime initialDate,
    required this.onRangeChanged,
  }) : _range = monthsAround(initialDate) {
    _controller.visibleDateTimeRange.addListener(_onVisibleRangeChanged);
  }

  final KalenderController _controller;
  final void Function(LoadedRange range) onRangeChanged;
  LoadedRange _range;
  bool _disposed = false;

  LoadedRange get range => _range;

  void _onVisibleRangeChanged() {
    final visible = _controller.visibleDateTimeRange.value;
    if (visible == null ||
        visible.end.difference(visible.start) > maxVisibleRange) {
      return;
    }
    final middle = visible.start.add(
      visible.end.difference(visible.start) ~/ 2,
    );
    final isInside =
        !middle.isBefore(_range.from) && middle.isBefore(_range.to);
    if (isInside) return;
    final needed = monthsAround(middle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || needed == _range) return;
      _range = needed;
      onRangeChanged(needed);
    });
  }

  void dispose() {
    _disposed = true;
    _controller.visibleDateTimeRange.removeListener(_onVisibleRangeChanged);
  }
}

/// Largeur à partir de laquelle la barre tient sur une ligne : la classe
/// « étendue » des tailles de fenêtre de Material 3.
const _wideToolbarWidth = 840.0;

/// Navigation (précédent, aujourd'hui, suivant) au centre, nom de la période
/// dessous, choix de la vue et [trailing] (actions propres à l'écran). Sur
/// un écran large, les vues sont à gauche de la navigation et les actions à
/// sa droite ; plus étroit, les vues passent sous la période, sur toute la
/// largeur.
class AgendaToolbar extends StatelessWidget {
  const AgendaToolbar({
    required this.view,
    required this.onViewChanged,
    required this.controller,
    required this.keys,
    this.trailing = const [],
    super.key,
  });

  final AgendaToolbarKeys keys;
  final AgendaView view;
  final ValueChanged<AgendaView> onViewChanged;
  final KalenderController controller;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.previousPeriod,
          icon: const Icon(Icons.chevron_left),
          onPressed: controller.animateToPreviousPage,
        ),
        TextButton(
          key: keys.today,
          onPressed: () => controller.animateToDate(DateTime.now()),
          child: Text(l10n.todayButton),
        ),
        IconButton(
          tooltip: l10n.nextPeriod,
          icon: const Icon(Icons.chevron_right),
          onPressed: controller.animateToNextPage,
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideToolbarWidth;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: kMinInteractiveDimension,
                child: NavigationToolbar(
                  leading: isWide
                      ? Center(
                          widthFactor: 1,
                          child: _viewSelector(l10n, fillWidth: false),
                        )
                      : null,
                  middle: FittedBox(fit: BoxFit.scaleDown, child: navigation),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: trailing,
                  ),
                ),
              ),
              _PeriodLabel(
                key: keys.period,
                controller: controller,
                view: view,
              ),
              if (!isWide) ...[
                const SizedBox(height: 4),
                _viewSelector(l10n, fillWidth: true),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Choix de la vue ; [fillWidth] : segments égaux sur toute la largeur.
  Widget _viewSelector(AppLocalizations l10n, {required bool fillWidth}) {
    ButtonSegment<AgendaView> segment(
      AgendaView value,
      String label,
      Key key,
    ) => ButtonSegment(
      value: value,
      label: Text(
        label,
        key: key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return SegmentedButton<AgendaView>(
      showSelectedIcon: false,
      expandedInsets: fillWidth ? EdgeInsets.zero : null,
      segments: [
        segment(AgendaView.day, l10n.viewDay, keys.day),
        segment(AgendaView.week, l10n.viewWeek, keys.week),
        segment(AgendaView.month, l10n.viewMonth, keys.month),
        segment(AgendaView.schedule, l10n.viewSchedule, keys.schedule),
      ],
      selected: {view},
      onSelectionChanged: (selection) => onViewChanged(selection.first),
    );
  }
}

/// Nom de la période que montre la page de kalender.
class _PeriodLabel extends StatefulWidget {
  const _PeriodLabel({required this.controller, required this.view, super.key});

  final KalenderController controller;
  final AgendaView view;

  @override
  State<_PeriodLabel> createState() => _PeriodLabelState();
}

class _PeriodLabelState extends State<_PeriodLabel> {
  KalenderDateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _range = widget.controller.visibleDateTimeRange.value;
    widget.controller.visibleDateTimeRange.addListener(_onRangeChanged);
  }

  @override
  void didUpdateWidget(_PeriodLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.visibleDateTimeRange.removeListener(_onRangeChanged);
    widget.controller.visibleDateTimeRange.addListener(_onRangeChanged);
    _range = widget.controller.visibleDateTimeRange.value;
  }

  @override
  void dispose() {
    widget.controller.visibleDateTimeRange.removeListener(_onRangeChanged);
    super.dispose();
  }

  /// kalender publie sa plage pendant sa propre construction : on la lit à
  /// la fin de l'image, et on en demande une si rien n'était prévu.
  void _onRangeChanged() {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _range = widget.controller.visibleDateTimeRange.value);
      })
      ..ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    return Text(
      range == null
          ? ''
          : agendaPeriodLabel(
              view: widget.view,
              start: range.start,
              end: range.end,
              l10n: AppLocalizations.of(context),
            ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}

/// Nom de la période qu'une page de [view] montre, du jour de [start] au
/// jour de [end] exclu, dans la langue de [l10n] : « Lundi 5 octobre 2026 »,
/// « 5 – 11 octobre 2026 », « 28 sept. – 4 oct. 2026 », « Octobre 2026 ».
///
/// La grille d'un mois déborde sur les mois voisins : elle porte, comme une
/// page du planning, le nom du mois de son milieu.
String agendaPeriodLabel({
  required AgendaView view,
  required DateTime start,
  required DateTime end,
  required AppLocalizations l10n,
}) {
  final locale = l10n.localeName;
  final first = DateTime(start.year, start.month, start.day);
  // Dernier jour par le calendrier, et non en retirant 24 h : la nuit d'un
  // changement d'heure n'en fait pas 24.
  final last = DateTime(end.year, end.month, end.day - 1);
  final label = switch (view) {
    AgendaView.day => DateFormat.yMMMMEEEEd(locale).format(first),
    AgendaView.week => _rangeLabel(first, last, l10n),
    AgendaView.month || AgendaView.schedule => DateFormat.yMMMM(locale).format(
      DateTime(
        first.year,
        first.month,
        first.day + last.difference(first).inDays ~/ 2,
      ),
    ),
  };
  return toBeginningOfSentenceCase(label, locale);
}

/// Du jour [first] au jour [last] inclus, en ne répétant ni le mois ni
/// l'année quand ils sont communs.
String _rangeLabel(DateTime first, DateTime last, AppLocalizations l10n) {
  final locale = l10n.localeName;
  if (first.year != last.year) {
    final date = DateFormat.yMMMd(locale);
    return '${date.format(first)} – ${date.format(last)}';
  }
  final year = DateFormat.y(locale).format(last);
  if (first.month != last.month) {
    final date = DateFormat.MMMd(locale);
    return l10n.agendaPeriodSameYear(
      date.format(first),
      date.format(last),
      year,
    );
  }
  final day = DateFormat.d(locale);
  return l10n.agendaPeriodSameMonth(
    day.format(first),
    day.format(last),
    DateFormat.MMMM(locale).format(last),
    year,
  );
}

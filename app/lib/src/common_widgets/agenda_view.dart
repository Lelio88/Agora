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
///   changement de plage est différé à la fin de l'image.
library;

import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
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

/// Configuration kalender de [view] ; la semaine se réduit à trois jours
/// sur un écran étroit.
ViewConfiguration agendaViewConfiguration(
  BuildContext context,
  AgendaView view,
) => switch (view) {
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

/// Navigation (précédent, aujourd'hui, suivant), choix de la vue, puis
/// [trailing] (actions propres à l'écran). Défilable : sur un téléphone
/// étroit, tout ne tient pas côte à côte.
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
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
          const SizedBox(width: 16),
          SegmentedButton<AgendaView>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AgendaView.day,
                label: Text(l10n.viewDay, key: keys.day),
              ),
              ButtonSegment(
                value: AgendaView.week,
                label: Text(l10n.viewWeek, key: keys.week),
              ),
              ButtonSegment(
                value: AgendaView.month,
                label: Text(l10n.viewMonth, key: keys.month),
              ),
              ButtonSegment(
                value: AgendaView.schedule,
                label: Text(l10n.viewSchedule, key: keys.schedule),
              ),
            ],
            selected: {view},
            onSelectionChanged: (selection) => onViewChanged(selection.first),
          ),
          if (trailing.isNotEmpty) const SizedBox(width: 8),
          ...trailing,
        ],
      ),
    );
  }
}

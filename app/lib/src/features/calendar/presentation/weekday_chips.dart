/// Les sept jours de la semaine, du lundi au dimanche, en initiales à
/// cocher : jours d'une répétition hebdomadaire (éditeur de rdv) ou jours
/// travaillés d'un proche (formulaire « Horaires de travail »).
///
/// Invariant : les jours sont ceux de `DateTime` (`DateTime.monday` …
/// `DateTime.sunday`) ; le parent décide de ce qu'un appui coche ou
/// décoche (il refuse par exemple de décocher le dernier jour).
library;

import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeekdayChips extends StatelessWidget {
  const WeekdayChips({
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final initial = DateFormat.EEEEE(locale);
    final full = DateFormat.EEEE(locale);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++
        )
          // Le 1er janvier 2024 est un lundi : son jour N tombe le N-ième
          // jour de la semaine.
          FilterChip(
            key: CalendarKeys.repeatWeekday(weekday),
            label: Text(initial.format(DateTime(2024, 1, weekday))),
            tooltip: full.format(DateTime(2024, 1, weekday)),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            selected: selected.contains(weekday),
            onSelected: (_) => onToggle(weekday),
          ),
      ],
    );
  }
}

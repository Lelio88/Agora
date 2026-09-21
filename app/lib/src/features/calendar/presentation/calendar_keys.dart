/// Clés de l'agenda et de l'éditeur de rdv, pour les tests.
library;

import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:flutter/widgets.dart';

abstract final class CalendarKeys {
  static const screen = ValueKey('calendar.screen');
  static const newEvent = ValueKey('calendar.newEvent');
  static const today = ValueKey('calendar.today');
  static const viewDay = ValueKey('calendar.viewDay');
  static const viewWeek = ValueKey('calendar.viewWeek');
  static const viewMonth = ValueKey('calendar.viewMonth');
  static const viewSchedule = ValueKey('calendar.viewSchedule');

  static const editor = ValueKey('calendar.editor');
  static const title = ValueKey('calendar.editor.title');
  static const location = ValueKey('calendar.editor.location');
  static const description = ValueKey('calendar.editor.description');
  static const allDay = ValueKey('calendar.editor.allDay');
  static const repeat = ValueKey('calendar.editor.repeat');
  static const visibility = ValueKey('calendar.editor.visibility');
  static const save = ValueKey('calendar.editor.save');
  static const delete = ValueKey('calendar.editor.delete');

  static const scopeOccurrence = ValueKey('calendar.scope.occurrence');
  static const scopeSeries = ValueKey('calendar.scope.series');

  /// Entrée du menu de répétition ; `null` pour « jamais ».
  static ValueKey<String> repeatOption(Frequency? frequency) =>
      ValueKey('calendar.editor.repeat.${frequency?.name ?? 'never'}');
}

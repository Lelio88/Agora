/// Clés de l'agenda, de l'éditeur de rdv et de la gestion des agendas,
/// pour les tests.
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
  static const manageCalendars = ValueKey('calendar.manageCalendars');

  static const editor = ValueKey('calendar.editor');
  static const title = ValueKey('calendar.editor.title');
  static const location = ValueKey('calendar.editor.location');
  static const description = ValueKey('calendar.editor.description');
  static const allDay = ValueKey('calendar.editor.allDay');
  static const repeat = ValueKey('calendar.editor.repeat');
  static const visibility = ValueKey('calendar.editor.visibility');
  static const eventCalendar = ValueKey('calendar.editor.calendar');
  static const save = ValueKey('calendar.editor.save');
  static const delete = ValueKey('calendar.editor.delete');

  static const scopeOccurrence = ValueKey('calendar.scope.occurrence');
  static const scopeSeries = ValueKey('calendar.scope.series');

  static const calendarsScreen = ValueKey('calendars.screen');
  static const newCalendar = ValueKey('calendars.new');
  static const calendarEditor = ValueKey('calendars.editor');
  static const calendarName = ValueKey('calendars.editor.name');
  static const calendarVisibility = ValueKey('calendars.editor.visibility');
  static const calendarSave = ValueKey('calendars.editor.save');
  static const calendarDelete = ValueKey('calendars.editor.delete');
  static const confirmDeleteCalendar = ValueKey('calendars.confirmDelete');

  /// Ligne d'un agenda dans « Mes agendas ».
  static ValueKey<String> calendarTile(String id) =>
      ValueKey('calendars.tile.$id');

  /// Case « afficher dans mon agenda » d'un agenda.
  static ValueKey<String> calendarShown(String id) =>
      ValueKey('calendars.shown.$id');

  /// Pastille de couleur de l'éditeur d'agenda.
  static ValueKey<String> calendarColor(String hex) =>
      ValueKey('calendars.editor.color.$hex');

  /// Agenda proposé dans le menu de l'éditeur de rdv.
  static ValueKey<String> eventCalendarOption(String id) =>
      ValueKey('calendar.editor.calendar.$id');

  /// Entrée du menu de répétition ; `null` pour « jamais ».
  static ValueKey<String> repeatOption(Frequency? frequency) =>
      ValueKey('calendar.editor.repeat.${frequency?.name ?? 'never'}');
}

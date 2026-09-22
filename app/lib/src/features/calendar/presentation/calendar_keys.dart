/// Clés de l'agenda, de l'éditeur de rdv, de la gestion et de l'import des
/// agendas, pour les tests.
library;

import 'package:agora/src/common_widgets/agenda_view.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:flutter/widgets.dart';

abstract final class CalendarKeys {
  static const screen = ValueKey('calendar.screen');
  static const newEvent = ValueKey('calendar.newEvent');
  // Barre commune des vues d'agenda (`common_widgets/agenda_view.dart`).
  static const toolbar = AgendaToolbarKeys('calendar');
  static final today = toolbar.today;
  static final viewDay = toolbar.day;
  static final viewWeek = toolbar.week;
  static final viewMonth = toolbar.month;
  static final viewSchedule = toolbar.schedule;
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
  static const calendarSyncNow = ValueKey('calendars.editor.syncNow');

  static const importCalendar = ValueKey('calendars.import');
  static const importScreen = ValueKey('calendars.import.screen');
  static const importUrl = ValueKey('calendars.import.url');
  static const importName = ValueKey('calendars.import.name');
  static const importSave = ValueKey('calendars.import.save');
  static const importHelp = ValueKey('calendars.import.help');

  static const importedEventSheet = ValueKey('calendar.imported.sheet');
  static const importedEventVisibility = ValueKey(
    'calendar.imported.visibility',
  );
  static const importedEventSave = ValueKey('calendar.imported.save');

  static const groupEventScreen = ValueKey('calendar.groupEvent');
  static const groupEventEdit = ValueKey('calendar.groupEvent.edit');
  static const groupEventDelete = ValueKey('calendar.groupEvent.delete');
  static const myResponse = ValueKey('calendar.groupEvent.myResponse');
  static const noResponseSection = ValueKey('calendar.groupEvent.noResponse');
  static const groupCalendarsHeader = ValueKey('calendars.groupsHeader');

  /// Bouton d'une réponse sur la fiche d'un rdv de groupe.
  static ValueKey<String> responseOption(ResponseStatus status) =>
      ValueKey('calendar.groupEvent.respond.${status.name}');

  /// Liste des membres ayant fait une réponse donnée.
  static ValueKey<String> responseSection(ResponseStatus status) =>
      ValueKey('calendar.groupEvent.responses.${status.name}');

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

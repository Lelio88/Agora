/// Lectures propres aux agendas de proches : leurs dates à retenir des
/// prochains jours (onglet Social) et l'agenda d'un proche (sa page).
///
/// Choix non évidents :
/// - une seule plage pour les deux, les [upcomingDays] jours qui commencent
///   à minuit aujourd'hui : stable dans la journée, elle reste en cache
///   d'un écran à l'autre ;
/// - on lit [agendaProvider], pas l'agenda visible : masquer un proche de
///   son agenda ne doit pas faire oublier son anniversaire ;
/// - sans proche, aucune requête : l'onglet Social se monte au démarrage.
library;

import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/contact_agenda.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jours couverts par « À venir » et par la page d'un proche.
const upcomingDays = 31;

/// Les [upcomingDays] jours qui commencent à minuit (local) le jour de [now].
AgendaRange upcomingRange(DateTime now) => AgendaRange(
  from: DateTime(now.year, now.month, now.day).toUtc(),
  to: DateTime(now.year, now.month, now.day + upcomingDays).toUtc(),
);

/// Les dates à retenir des proches, des [upcomingDays] prochains jours.
final upcomingAnniversariesProvider =
    FutureProvider.autoDispose<List<Anniversary>>((ref) async {
      final calendars = await ref.watch(calendarsProvider.future);
      final contacts = {
        for (final calendar in calendars)
          if (calendar.isContact) calendar.id,
      };
      if (contacts.isEmpty) return const [];
      final now = DateTime.now();
      final items = await ref.watch(agendaProvider(upcomingRange(now)).future);
      return upcomingAnniversaries(
        items,
        contactCalendarIds: contacts,
        today: now,
      );
    });

/// L'agenda d'un proche, sur les [upcomingDays] prochains jours.
final contactAgendaProvider = FutureProvider.autoDispose
    .family<List<AgendaItem>, String>((ref, calendarId) async {
      final items = await ref.watch(
        agendaProvider(upcomingRange(DateTime.now())).future,
      );
      return items
          .where((item) => item.calendarId == calendarId)
          .toList(growable: false);
    });

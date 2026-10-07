/// Textes des temps de trajet, partagés par la fiche d'un rdv et la bande
/// de l'agenda.
///
/// Choix non évident : la durée s'arrondit à la minute supérieure et porte
/// toujours « ≈ » : l'IGN ne connaît ni le trafic ni le temps de se garer.
library;

import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

/// « ≈ 14 min », « ≈ 1 h 05 ».
String travelDurationLabel(Duration duration, AppLocalizations l10n) {
  final minutes = (duration.inSeconds / 60).ceil();
  if (minutes < 60) return l10n.travelMinutes(minutes);
  return l10n.travelHoursMinutes(
    minutes ~/ 60,
    (minutes % 60).toString().padLeft(2, '0'),
  );
}

IconData travelModeIcon(TravelMode mode) => switch (mode) {
  TravelMode.car => Icons.directions_car_outlined,
  TravelMode.walk => Icons.directions_walk,
};

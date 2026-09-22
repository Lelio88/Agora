/// Palette de l'app : couleurs des agendas et des membres d'un groupe.
///
/// La base garde une couleur en `#RRGGBB` ; l'app propose une palette
/// courte, lisible en thème clair comme en sombre. Sans couleur, on prend
/// celle du thème. Un texte posé dessus est clair ou foncé selon la
/// luminance du fond.
library;

import 'package:flutter/material.dart';

const appPalette = [
  '#1E88E5',
  '#43A047',
  '#E53935',
  '#FB8C00',
  '#8E24AA',
  '#00ACC1',
  '#6D4C41',
  '#546E7A',
];

/// Couleur `#RRGGBB` ; [fallback] si elle est absente ou mal formée.
Color colorFromHex(String? hex, Color fallback) {
  final value = hex == null || hex.length != 7
      ? null
      : int.tryParse(hex.substring(1), radix: 16);
  return value == null ? fallback : Color(0xFF000000 | value);
}

/// Texte lisible sur [background].
Color readableOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black87;

/// Journalisation d'Agora : la seule surface qui écrit des logs.
///
/// Les services et contrôleurs ne journalisent jamais eux-mêmes ; les erreurs
/// des providers remontent via `AsyncErrorLogger`. Brancher un collecteur de
/// crashs plus tard revient à remplacer [DeveloperAppLogger] à la composition
/// root, sans toucher aux appelants.
library;

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class AppLogger {
  void debug(String message, {Object? error, StackTrace? stackTrace});
  void info(String message, {Object? error, StackTrace? stackTrace});
  void warning(String message, {Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace});
}

/// Implémentation par défaut : `dart:developer`, visible dans DevTools et
/// `flutter logs`, sans rien envoyer hors de l'appareil.
final class DeveloperAppLogger implements AppLogger {
  const DeveloperAppLogger();

  // Niveaux de package:logging, que DevTools sait filtrer.
  static const _debug = 500;
  static const _info = 800;
  static const _warning = 900;
  static const _error = 1000;

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(_debug, message, error, stackTrace);

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(_info, message, error, stackTrace);

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(_warning, message, error, stackTrace);

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(_error, message, error, stackTrace);

  void _log(int level, String message, Object? error, StackTrace? trace) =>
      developer.log(
        message,
        name: 'agora',
        level: level,
        error: error,
        stackTrace: trace,
      );
}

final appLoggerProvider = Provider<AppLogger>(
  (ref) => const DeveloperAppLogger(),
);

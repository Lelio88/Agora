import 'package:agora/src/logging/app_logger.dart';

/// Faux [AppLogger] qui enregistre chaque appel, pour asserter ce qui a été
/// journalisé plutôt que de vérifier des appels de mock.
class RecordingAppLogger implements AppLogger {
  final logs = <(String level, String message, Object? error, StackTrace?)>[];

  int get errorCount => logs.where((log) => log.$1 == 'error').length;

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      logs.add(('debug', message, error, stackTrace));

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) =>
      logs.add(('info', message, error, stackTrace));

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      logs.add(('warning', message, error, stackTrace));

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      logs.add(('error', message, error, stackTrace));
}

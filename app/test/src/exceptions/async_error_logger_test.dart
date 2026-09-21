import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/async_error_logger.dart';
import 'package:agora/src/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recording_app_logger.dart';

void main() {
  late RecordingAppLogger logger;
  late ProviderContainer container;

  setUp(() {
    logger = RecordingAppLogger();
    container = ProviderContainer(
      // Riverpod 3 relance un provider en échec : sans ceci, `.future` ne se
      // termine jamais et le test attend son délai maximal.
      retry: (retryCount, error) => null,
      observers: [AsyncErrorLogger()],
      overrides: [appLoggerProvider.overrideWithValue(logger)],
    );
    addTearDown(container.dispose);
  });

  test('logs the error of a failing async provider once', () async {
    final failing = FutureProvider<int>((ref) async {
      throw const UnknownException();
    });

    await expectLater(container.read(failing.future), throwsA(anything));

    expect(logger.errorCount, 1);
    expect(logger.logs.single.$3, isA<UnknownException>());
  });

  test('does not log a successful async provider', () async {
    final succeeding = FutureProvider<int>((ref) async => 42);

    await container.read(succeeding.future);

    expect(logger.errorCount, 0);
  });
}

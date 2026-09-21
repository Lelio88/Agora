/// Observateur Riverpod qui transmet à [AppLogger] toute erreur portée par un
/// provider asynchrone, pour qu'aucune ne passe en silence.
///
/// Choix non évident : le filtre porte sur `hasError` et non sur
/// `is AsyncError`, car Riverpod 3 fait transiter les nouvelles tentatives par
/// un `AsyncLoading` qui garde l'erreur précédente. La déduplication compare
/// l'objet d'erreur par référence : une même erreur n'est journalisée qu'une
/// fois, même si l'état est réémis.
library;

import 'package:agora/src/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AsyncErrorLogger extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (newValue is! AsyncValue || !newValue.hasError) return;
    if (previousValue is AsyncValue &&
        previousValue.hasError &&
        identical(previousValue.error, newValue.error)) {
      return;
    }
    final provider = context.provider;
    context.container
        .read(appLoggerProvider)
        .error(
          'Provider error: ${provider.name ?? provider.runtimeType}',
          error: newValue.error,
          stackTrace: newValue.stackTrace,
        );
  }
}

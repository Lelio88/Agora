/// Adapte un flux en `Listenable`, pour le `refreshListenable` de GoRouter :
/// chaque événement du flux fait réévaluer la redirection.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

final class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

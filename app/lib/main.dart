/// Point d'entrée d'Agora : valide la configuration, initialise Supabase, puis
/// monte l'app sous la composition root.
///
/// Invariant : la configuration est validée avant toute initialisation. Une
/// configuration incomplète fait planter le démarrage de façon visible au
/// lieu de viser le mauvais backend.
library;

import 'package:agora/src/app.dart';
import 'package:agora/src/composition_root.dart';
import 'package:agora/src/exceptions/async_error_logger.dart';
import 'package:agora/src/supabase/supabase_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = SupabaseConfig.fromEnvironment();
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
  );
  runApp(
    ProviderScope(
      observers: [AsyncErrorLogger()],
      overrides: prodOverrides,
      child: const AgoraApp(),
    ),
  );
}

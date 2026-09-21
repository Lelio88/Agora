/// Configuration de connexion au backend Supabase d'Agora, lue au build par
/// `--dart-define-from-file=config/<env>.json`.
///
/// Choix non évident : l'URL et la clé ne tombent **jamais** sur une valeur
/// par défaut. Sur DewDrop, une URL de prod passée sans sa clé retombait sur
/// la clé locale et chaque appel échouait en 401 muet. Ici, une configuration
/// incomplète fait échouer le démarrage.
///
/// Invariants :
/// - l'URL et la clé sont fournies ensemble ;
/// - `http` n'est admis que vers une machine locale (dont `10.0.2.2`, l'hôte
///   vu depuis l'émulateur Android) ; tout le reste passe en `https`.
library;

/// Hôtes joignables en clair : poste de dev et émulateur Android.
const _localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};

final class SupabaseConfig {
  const SupabaseConfig._({required this.url, required this.publishableKey});

  /// Lit `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY` injectés à la compilation.
  factory SupabaseConfig.fromEnvironment() => parse(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  /// Valide une configuration ; lève [StateError] si elle est incomplète ou
  /// si elle viserait un hôte distant en clair.
  static SupabaseConfig parse({
    required String url,
    required String publishableKey,
  }) {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY doivent être fournis ensemble : '
        'lancer avec --dart-define-from-file=config/local.json.',
      );
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL invalide : « $url ».');
    }
    final isSecure = uri.scheme == 'https';
    final isLocalHttp = uri.scheme == 'http' && _localHosts.contains(uri.host);
    if (!isSecure && !isLocalHttp) {
      throw StateError(
        'SUPABASE_URL doit être en https hors du poste de dev : « $url ».',
      );
    }
    return SupabaseConfig._(url: url, publishableKey: publishableKey);
  }

  final String url;

  /// Clé publique (rôle `anon`) : elle n'est pas secrète, la RLS protège les
  /// données. La clé `service_role` n'entre jamais dans l'app.
  final String publishableKey;
}

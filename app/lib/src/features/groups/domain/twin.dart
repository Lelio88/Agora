/// Jumelage d'un groupe Agora avec un groupe d'une autre app du conteneur
/// (Arpente) : les apps jumelles, le jumeau d'un groupe, et les liens du
/// protocole commun (`docs/liens-inter-apps.md` du dépôt méta).
///
/// Les deux apps ne se parlent pas : elles s'ouvrent l'une l'autre par des
/// liens préremplis, et la personne valide dans l'app d'arrivée.
///
/// Choix non évidents :
/// - les paramètres voyagent dans le **fragment** : un code ouvre un groupe,
///   et une requête finirait dans les journaux de l'hébergeur de l'autre app
///   (GitHub Pages pour Arpente) quand l'app n'est pas installée ;
/// - un lien reçu n'est jamais gardé tel quel : seuls l'app (liste fermée) et
///   un code validé par son format en sont tirés, et les adresses sont
///   reconstruites depuis la base fixe de l'app jumelle. Un lien forgé ne
///   peut donc envoyer personne vers un autre site ;
/// - le nom proposé est du texte : caractères de contrôle et de mise en
///   forme (dont l'inversion bidirectionnelle) retirés, 60 caractères au plus.
///
/// Invariant : [parseTwinLink] rend `null` pour tout lien qu'une app ne doit
/// pas suivre — jamais un lien à moitié valide.
///
/// ```dart
/// final link = parseTwinLink(state.uri.queryParameters);
/// switch (link) {
///   case TwinRequest(): // proposer de jumeler un groupe
///   case TwinResponse(): // compléter un jumelage lancé depuis cet appareil
///   case null: // lien à ignorer
/// }
/// ```
library;

import 'dart:convert';
import 'dart:math';

/// Les apps avec lesquelles un groupe peut se jumeler.
enum TwinApp {
  arpente(
    displayName: 'Arpente',
    codeLength: 6,
    twinPage: 'https://arpente.heianenterprise.com/jumeler.html',
    joinPage: 'https://arpente.heianenterprise.com/rejoindre.html',
  );

  const TwinApp({
    required this.displayName,
    required this.codeLength,
    required this.twinPage,
    required this.joinPage,
  });

  /// Nom de l'app, une marque : le même dans toutes les langues.
  final String displayName;

  /// Longueur du code d'un groupe dans cette app.
  final int codeLength;

  /// Page de l'app qui reçoit les liens de jumelage.
  final String twinPage;

  /// Page de l'app qui fait rejoindre un groupe par son code.
  final String joinPage;

  /// La valeur de `de` qui désigne cette app, ou `null`.
  static TwinApp? fromCode(String? code) =>
      values.where((app) => app.name == code).firstOrNull;

  /// Un code de groupe de cette app, en majuscules (casse ignorée).
  bool acceptsCode(String code) =>
      RegExp('^[A-HJ-NP-Z2-9]{$codeLength}\$').hasMatch(code);

  /// Rejoindre le groupe jumeau dans cette app.
  Uri joinUri(String code) =>
      Uri.parse(joinPage).replace(fragment: _fragment({'code': code}));

  Uri _twinUri(Map<String, String> params) =>
      Uri.parse(twinPage).replace(fragment: _fragment(params));
}

/// Le jumeau d'un groupe dans une autre app, tel que ses membres le voient.
final class GroupTwin {
  const GroupTwin({
    required this.app,
    required this.inviteCode,
    this.remoteCode,
  });

  final TwinApp app;

  /// L'invitation (sans échéance) donnée à l'autre app pour rejoindre ce
  /// groupe ; la supprimer défait le jumelage.
  final String inviteCode;

  /// Le code pour rejoindre le groupe jumeau ; `null` tant que l'autre app
  /// n'a pas répondu.
  final String? remoteCode;

  bool get isPending => remoteCode == null;
}

/// Un lien de jumelage reçu d'une autre app, déjà validé.
sealed class TwinLink {
  const TwinLink({
    required this.app,
    required this.remoteCode,
    required this.state,
  });

  /// L'app qui envoie le lien.
  final TwinApp app;

  /// Le code pour rejoindre son groupe.
  final String remoteCode;

  /// Le jeton de l'app qui a lancé le jumelage, à renvoyer tel quel.
  final String state;
}

/// Une autre app propose de jumeler l'un de ses groupes avec un groupe
/// Agora.
final class TwinRequest extends TwinLink {
  const TwinRequest({
    required super.app,
    required super.remoteCode,
    required super.state,
    this.name,
  });

  /// Le nom proposé au groupe jumeau ; `null` s'il n'en reste rien.
  final String? name;
}

/// L'autre app répond à un jumelage lancé depuis Agora.
final class TwinResponse extends TwinLink {
  const TwinResponse({
    required super.app,
    required super.remoteCode,
    required super.state,
    required this.forCode,
  });

  /// L'invitation Agora envoyée dans la demande : elle désigne le groupe.
  final String forCode;
}

final _agoraCode = RegExp(r'^[A-HJ-NP-Z2-9]{8}$');
final _stateToken = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

/// Lit les paramètres d'un lien de jumelage ; `null` s'il ne faut pas le
/// suivre.
TwinLink? parseTwinLink(Map<String, String> params) {
  final app = TwinApp.fromCode(params['de']);
  final code = params['code']?.trim().toUpperCase();
  final state = params['etat'];
  if (app == null ||
      code == null ||
      !app.acceptsCode(code) ||
      state == null ||
      !_stateToken.hasMatch(state)) {
    return null;
  }
  final forCode = params['pour']?.trim().toUpperCase();
  if (forCode != null) {
    if (!_agoraCode.hasMatch(forCode)) return null;
    return TwinResponse(
      app: app,
      remoteCode: code,
      state: state,
      forCode: forCode,
    );
  }
  return TwinRequest(
    app: app,
    remoteCode: code,
    state: state,
    name: cleanTwinName(params['nom']),
  );
}

const _maxNameLength = 60;

/// Contrôle (Cc) et mise en forme (Cf : inversion bidirectionnelle, espaces
/// de largeur nulle) : rien de cela n'a sa place dans un nom de groupe.
final _hiddenCharacters = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);

/// Un nom de groupe reçu par lien, réduit à du texte lisible ; `null` s'il
/// n'en reste rien.
String? cleanTwinName(String? raw) {
  if (raw == null) return null;
  final text = raw
      .replaceAll(_hiddenCharacters, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return null;
  final runes = text.runes;
  return runes.length <= _maxNameLength
      ? text
      : String.fromCharCodes(runes.take(_maxNameLength)).trimRight();
}

/// La demande qu'Agora envoie à [app] : rejoindre ce groupe avec
/// [inviteCode], le jumeau à nommer [name].
Uri twinRequestUri(
  TwinApp app, {
  required String inviteCode,
  required String name,
  required String state,
}) => app._twinUri({
  'de': 'agora',
  'code': inviteCode,
  'nom': name,
  'etat': state,
});

/// La réponse d'Agora à une demande de [app] pour son groupe [forCode].
Uri twinResponseUri(
  TwinApp app, {
  required String inviteCode,
  required String forCode,
  required String state,
}) => app._twinUri({
  'de': 'agora',
  'code': inviteCode,
  'pour': forCode,
  'etat': state,
});

/// Un jeton neuf pour un jumelage lancé depuis cet appareil : 16 octets
/// aléatoires, en base64 URL sans remplissage (22 caractères).
String newTwinState([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _fragment(Map<String, String> params) =>
    Uri(queryParameters: params).query;

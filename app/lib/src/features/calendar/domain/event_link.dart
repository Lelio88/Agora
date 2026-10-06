/// Un rdv préparé dans une autre app du conteneur (Arpente : la sortie d'un
/// parcours de groupe), reçu par le lien `#/event?…` du protocole commun
/// (`docs/liens-inter-apps.md` du dépôt méta, §Ajouter un rdv dans Agora).
///
/// Le lien ne fait que préremplir l'éditeur : la personne choisit où va le
/// rdv et le vérifie avant de l'enregistrer. Il va dans un seul sens, sans
/// jeton ni réponse.
///
/// Choix non évidents :
/// - `debut` doit porter son décalage (`+02:00` ou `Z`) : une heure nue
///   serait lue dans le fuseau de l'appareil qui ouvre le lien, pas dans
///   celui de l'app qui l'a préparé ;
/// - les textes sont du texte : caractères de contrôle et de mise en forme
///   (dont l'inversion bidirectionnelle) retirés, longueurs du protocole ;
///   seule la description garde ses retours à la ligne ;
/// - `groupe` ne sert qu'à présélectionner un groupe : un code mal formé
///   retire la présélection, pas le rdv.
///
/// Invariant : [parseEventLink] rend `null` pour tout lien sans expéditeur
/// connu, titre, début avec décalage ou durée dans les bornes — jamais un
/// rdv à moitié lu.
///
/// ```dart
/// final link = parseEventLink(state.uri.queryParameters);
/// if (link != null) { /* ouvrir l'éditeur sur link.start → link.end */ }
/// ```
library;

/// Les apps qui envoient un rdv à Agora.
enum EventLinkSender {
  arpente(displayName: 'Arpente');

  const EventLinkSender({required this.displayName});

  /// Nom de l'app, une marque : le même dans toutes les langues.
  final String displayName;

  /// La valeur de `de` qui désigne cette app, ou `null`.
  static EventLinkSender? fromCode(String? code) =>
      values.where((app) => app.name == code).firstOrNull;
}

/// Un rdv reçu par lien, déjà validé et nettoyé.
final class EventLink {
  const EventLink({
    required this.sender,
    required this.title,
    required this.start,
    required this.duration,
    this.location,
    this.description,
    this.groupCode,
  });

  final EventLinkSender sender;
  final String title;

  /// Début, en UTC.
  final DateTime start;
  final Duration duration;
  final String? location;
  final String? description;

  /// L'invitation du groupe Agora à présélectionner (le jumeau du groupe de
  /// l'app qui envoie) ; jamais gardée ni recopiée dans le rdv.
  final String? groupCode;

  DateTime get end => start.add(duration);
}

const _maxTitleLength = 200;
const _maxLocationLength = 300;
const _maxDescriptionLength = 2000;
const _minDurationMinutes = 5;
const _maxDurationMinutes = 1440;

final _offset = RegExp(r'(Z|[+-]\d{2}:\d{2})$');
final _wholeNumber = RegExp(r'^\d{1,4}$');
final _groupCode = RegExp(r'^[A-HJ-NP-Z2-9]{8}$');

/// Lit les paramètres d'un lien de rdv ; `null` s'il ne faut pas le suivre.
EventLink? parseEventLink(Map<String, String> params) {
  final sender = EventLinkSender.fromCode(params['de']);
  final title = cleanLinkText(params['titre'], maxLength: _maxTitleLength);
  final start = _instant(params['debut']);
  final duration = _duration(params['duree']);
  if (sender == null || title == null || start == null || duration == null) {
    return null;
  }
  final code = params['groupe']?.trim().toUpperCase();
  return EventLink(
    sender: sender,
    title: title,
    start: start,
    duration: duration,
    location: cleanLinkText(params['lieu'], maxLength: _maxLocationLength),
    description: cleanLinkText(
      params['description'],
      maxLength: _maxDescriptionLength,
      multiline: true,
    ),
    groupCode: code != null && _groupCode.hasMatch(code) ? code : null,
  );
}

DateTime? _instant(String? raw) {
  final value = raw?.trim();
  if (value == null || !_offset.hasMatch(value)) return null;
  return DateTime.tryParse(value)?.toUtc();
}

Duration? _duration(String? raw) {
  final value = raw?.trim();
  if (value == null || !_wholeNumber.hasMatch(value)) return null;
  final minutes = int.parse(value);
  if (minutes < _minDurationMinutes || minutes > _maxDurationMinutes) {
    return null;
  }
  return Duration(minutes: minutes);
}

/// Contrôle (Cc) et mise en forme (Cf : inversion bidirectionnelle, espaces
/// de largeur nulle).
final _hiddenCharacters = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);

/// Un texte reçu par lien, réduit à du texte lisible et coupé à [maxLength]
/// caractères ; `null` s'il n'en reste rien. [multiline] garde les retours à
/// la ligne (`\r\n` devient `\n`) ; les autres blancs se replient en une
/// espace.
String? cleanLinkText(
  String? raw, {
  required int maxLength,
  bool multiline = false,
}) {
  if (raw == null) return null;
  final lines = multiline ? raw.replaceAll('\r\n', '\n').split('\n') : [raw];
  final text = lines
      .map(
        (line) => line
            .replaceAll(_hiddenCharacters, ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
      )
      .join('\n')
      .trim();
  if (text.isEmpty) return null;
  final runes = text.runes;
  return runes.length <= maxLength
      ? text
      : String.fromCharCodes(runes.take(maxLength)).trimRight();
}

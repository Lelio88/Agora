/// Une adresse située — son libellé et son point — et la recherche qui la
/// propose pendant la frappe.
///
/// Choix non évidents :
/// - le libellé est celui du service d'adresses, pas le texte tapé : c'est
///   lui qui part vers l'app d'itinéraire (« Y aller »), et il désigne une
///   adresse que le service sait placer ;
/// - [isSearchableAddress] reprend les bornes du service de l'IGN (de 3 à
///   200 caractères, commençant par une lettre ou un chiffre) : en deçà, il
///   répond par une erreur, inutile de l'appeler.
///
/// Invariant : fonctions pures, sans E/S.
library;

final class Address {
  const Address({
    required this.label,
    required this.longitude,
    required this.latitude,
  });

  /// Libellé complet, prêt à afficher (« 1 Place de l'Hôtel de Ville 51100
  /// Reims »).
  final String label;

  /// Coordonnées WGS 84, en degrés.
  final double longitude;
  final double latitude;

  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.label == label &&
      other.longitude == longitude &&
      other.latitude == latitude;

  @override
  int get hashCode => Object.hash(label, longitude, latitude);

  @override
  String toString() => 'Address($label)';
}

/// Recherche d'adresses pendant la frappe.
///
/// Invariant : seules des `AppException` en sortent.
abstract interface class AddressSearch {
  /// Les adresses qui répondent à [text], la plus probable d'abord ; vide
  /// sans rien demander si [text] ne se cherche pas encore
  /// ([isSearchableAddress]).
  Future<List<Address>> search(String text);
}

final _startsWithLetterOrDigit = RegExp(r'^[\p{L}\p{N}]', unicode: true);

/// Vrai si [text], une fois débarrassé de ses espaces, peut être cherché.
bool isSearchableAddress(String text) {
  final trimmed = text.trim();
  return trimmed.length >= 3 &&
      trimmed.length <= 200 &&
      _startsWithLetterOrDigit.hasMatch(trimmed);
}

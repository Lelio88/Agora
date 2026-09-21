/// Utilisateur connecté, réduit à ce dont l'app a besoin.
///
/// L'égalité porte sur les valeurs : un rafraîchissement de jeton réémet le
/// même utilisateur, et Riverpod ne reconstruit alors rien.
library;

final class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

# Comptes et authentification — annexe d'architecture

Annexe de [`architecture.md`](./architecture.md) §7. Elle décrit la connexion par e-mail, le
profil et les gabarits d'e-mail. Les réglages d'hébergement (variables `GOTRUE_*`, gabarits
servis par URL, CAPTCHA) sont au §10 de l'index.

## Parcours et règles

- **E-mail + mot de passe, confirmés par un code à 6 chiffres**, jamais par un lien : pas de deep
  link ni de liste de redirections, et le mail se lit sur n'importe quel appareil. Même principe
  pour le mot de passe oublié (code, puis nouveau mot de passe). Google et Discord s'ajoutent
  comme fournisseurs OAuth (identité seule).
- **Politique de mot de passe** : 8 caractères, lettres et chiffres (`minimum_password_length`,
  `password_requirements`). `credential_rules.dart` applique la même règle **avant** l'envoi. Un
  refus du serveur après coup aurait déjà consommé le code de réinitialisation.
- **Codes GoTrue traduits** (`auth_error_translator.dart`) : `invalid_credentials`,
  `email_not_confirmed`, `user_already_exists`, `otp_expired` (code faux **ou** expiré),
  `weak_password`, `validation_failed`, `over_*_rate_limit`. Les pannes réseau se reconnaissent
  au texte (`network_errors.dart`), car le SDK les emballe parfois dans une `AuthException` sans
  code.
- **Anti-énumération** : compte inconnu et mauvais mot de passe donnent le même message ;
  « mot de passe oublié » réussit pour toute adresse. Seule l'inscription dit « un compte existe
  déjà », choix assumé pour ne pas faire attendre un code qui ne viendra jamais. GoTrue le
  signale soit par `user_already_exists`, soit par un utilisateur **sans identité** : les deux
  sont traités. `email_not_confirmed` (et donc le bouton « Recevoir un code de confirmation »)
  ne révèle rien : GoTrue vérifie le mot de passe **avant** la confirmation, si bien qu'un mauvais
  mot de passe sur un compte non confirmé répond `invalid_credentials`, comme un compte inconnu
  (vérifié sur le serveur local).
- **Codes valables 15 minutes** (`otp_expiry = 900`) : un code de réinitialisation deviné donne
  le compte, et la seule limite est `token_verifications` (30 essais / 5 min / IP). La
  réinitialisation vérifie **toujours** le code, même avec une session ouverte.
- **Navigation** : après une connexion ou un code juste, l'écran ne navigue pas. C'est le routeur
  qui redirige, sur l'événement de session (`refreshListenable`). `/reset-password` reste ouvert
  aux deux états : le code ouvre une session **avant** l'enregistrement du mot de passe. Pendant
  une action, `AuthScaffold(busy:)` neutralise tout l'écran, liens compris : changer d'écran en
  pleine requête ferait rediriger le routeur depuis l'écran suivant. `/verify-email` et
  `/reset-password` exigent le paramètre `email`, faute de quoi ils renvoient à la connexion.
- **Contrôleurs** : un `AuthActionController` par action (`auth_action_controller.dart`), qui
  n'écrit son état qu'après avoir vérifié `ref.mounted`. Réussir fait quitter l'écran pendant
  l'`await`.
- **Profil** : nom affiché, langue (`fr`/`en`) et fuseau. Langue et fuseau partent à
  l'inscription (métadonnées `locale`, `timezone`), et le trigger d'inscription les valide avec
  repli. La **langue du profil pilote celle de l'app** (`app.dart`) **et celle des e-mails** :
  `private.sync_profile_locale` la recopie dans `auth.users.raw_user_meta_data`, seule source que
  lisent les gabarits. Un fuseau inconnu de Postgres est refusé (`invalid_timezone`).

## Suppression du compte

- **Exigée par le Play Store** pour toute app qui crée des comptes, dans l'app **et** par une
  adresse web : la version web d'Agora (profil → « Supprimer mon compte ») sert de lien pour la
  fiche Play.
- Écran de profil → dialogue qui expose les conséquences → RPC `public.delete_my_account()`
  (`SECURITY DEFINER`, migration `account_deletion`), puis fermeture de la session.
- **Groupes possédés transmis** dans la même transaction : à l'admin le plus ancien, sinon au
  membre le plus ancien. Un groupe sans autre membre est supprimé, avec son agenda et ses rdv.
  Un groupe ne reste jamais sans propriétaire : la RPC verrouille d'abord, dans un ordre fixe,
  chaque groupe dont la personne est membre, puis relit son rôle. Deux suppressions simultanées
  dans un même groupe (propriétaire et héritier) se sérialisent ainsi. pgTAP ne tournant que dans
  une session, `supabase/checks/account_deletion_race.sh` rejoue ce cas avec deux sessions.
- **Tout le reste part en cascade** depuis `auth.users` : profil, agendas personnels, rdv et
  occurrences, URL iCal, appartenances, identités et sessions GoTrue. Les rdv de groupe proposés
  par la personne restent, sans auteur (contenu partagé), **avec leur texte libre** (titre, lieu,
  description), qui peut la nommer. La politique de confidentialité doit le dire.
- **RPC plutôt qu'Edge Function** : le Supabase auto-hébergé n'a pas d'edge runtime.
- **Après la RPC**, `signOut` retire la session locale **avant** d'appeler le serveur ; le 403
  que renvoie `/logout` pour un utilisateur disparu est normal et ignoré.
- **Session orpheline** : un compte supprimé ailleurs laisse sur les autres appareils un jeton
  d'accès valide jusqu'à son expiration (1 h). `currentProfileProvider` ferme toute session
  dont l'utilisateur n'a plus de profil. Le profil naît dans la même transaction que le compte,
  donc son absence ne peut pas être un simple retard.

## Gabarits d'e-mail

- `supabase/templates/*.html` : **tous** les gabarits que GoTrue peut envoyer sont surchargés
  (`confirmation`, `recovery`, `email_change`, `magic_link`, `reauthentication`, `invite`). Un
  seul oublié partirait en anglais, avec le gabarit intégré, sans aucune alerte.
- Bilingues par `{{ if eq .Data.locale "en" }}`, le français par défaut. Les sujets ne sont pas
  conditionnels et portent donc les deux langues.
- Vérification locale : Mailpit (`http://127.0.0.1:55324`, API `/api/v1/messages`).

## Fichiers

| Fichier | Rôle |
|---|---|
| `app/lib/src/features/auth/domain/auth_repository.dart` | Contrat : inscription, code, connexion, réinitialisation, déconnexion |
| `app/lib/src/features/auth/data/supabase_auth_repository.dart` | Implémentation GoTrue ; utilisateur sans identité → adresse déjà prise |
| `app/lib/src/features/auth/data/auth_error_translator.dart` | Codes GoTrue → `AppException` |
| `app/lib/src/features/auth/domain/credential_rules.dart` | Règles de saisie, alignées sur `config.toml` |
| `app/lib/src/features/auth/presentation/` | Cinq écrans, `AuthActionController`, `AuthScaffold(busy:)`, `AuthKeys` |
| `app/lib/src/features/profile/` | Profil : lecture/écriture de `profiles`, écran, contrôleur |
| `supabase/migrations/20260921171319_profile_locale_timezone.sql` | Langue et fuseau à l'inscription, validation du fuseau, recopie de la langue |
| `supabase/migrations/20260921175536_account_deletion.sql` | `delete_my_account()` : transmission des groupes, puis effacement en cascade |
| `supabase/templates/*.html` | Gabarits bilingues |

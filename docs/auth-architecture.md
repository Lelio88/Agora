# Comptes et authentification — annexe d'architecture

Annexe de [`architecture.md`](./architecture.md) §7. Elle décrit la connexion par e-mail, le
profil et les gabarits d'e-mail. Les réglages d'hébergement (variables `GOTRUE_*`, gabarits
servis par URL, CAPTCHA) sont au §10 de l'index.

## Parcours et règles

- **E-mail + mot de passe, confirmés par un code à 6 chiffres**, jamais par un lien : pas de deep
  link ni de liste de redirections, et le mail se lit sur n'importe quel appareil. Même principe
  pour le mot de passe oublié (code, puis nouveau mot de passe).
- **« Continuer avec Google / Discord »** (`SocialSignInButtons`, sous les formulaires de
  connexion et d'inscription) : `signInWithOAuth`, flux PKCE. Au retour, Android reçoit
  `app.agora://login-callback` et le web revient sur sa page (`oauth_callback.dart`, adresses
  dans `ADDITIONAL_REDIRECT_URLS`). Le même geste crée le compte ou y reconnecte. Une adresse
  déjà connue, vérifiée par le fournisseur, retrouve son compte : GoTrue y **relie**
  l'identité. Le profil naît du trigger d'inscription, qui prend le nom du fournisseur ; la
  langue et le fuseau retombent sur `fr` et `Europe/Paris`, réglables dans le profil. Les
  boutons proposés viennent du build (`AGORA_SIGN_IN_PROVIDERS=google,discord`) : un bouton
  vers un fournisseur que GoTrue n'a pas activé mènerait à une page d'erreur, si bien que le
  build et le `.env` du serveur se règlent ensemble. Pas de CAPTCHA sur ce chemin : le
  fournisseur vérifie la personne, et aucun e-mail d'Agora n'est envoyé.
- **Écran de consentement Google** (projet Google Cloud « Agora », branding validé et publié) :
  il tient à trois choses à ne pas casser. D'abord, la page d'accueil déclarée,
  `/presentation.html`, lisible sans compte et qui explique l'app. Ensuite, les liens vers les
  pages légales. Enfin, la propriété de `heianenterprise.com`, prouvée dans Google Search
  Console par un enregistrement TXT chez Cloudflare. Les accès demandés restent `openid`,
  `email` et `profile`, qui ne demandent aucune vérification : en ajouter un (l'agenda, par
  exemple) relancerait l'examen de Google.
- **Politique de mot de passe** : 8 caractères, lettres et chiffres (`minimum_password_length`,
  `password_requirements`). `credential_rules.dart` applique la même règle **avant** l'envoi. Un
  refus du serveur après coup aurait déjà consommé le code de réinitialisation.
- **Codes GoTrue traduits** (`auth_error_translator.dart`) : `invalid_credentials`,
  `email_not_confirmed`, `user_already_exists`, `otp_expired` (code faux **ou** expiré),
  `weak_password`, `validation_failed`, `over_*_rate_limit`. Les pannes réseau se reconnaissent
  au texte (`network_errors.dart`), car le SDK les emballe parfois dans une `AuthException` sans
  code.
- **Anti-énumération** : compte inconnu et mauvais mot de passe donnent le même message ;
  « mot de passe oublié » réussit pour toute adresse ; **l'inscription répond pareil** qu'une
  adresse ait déjà un compte ou non (`blindSignUp`). GoTrue signale un doublon soit par un
  utilisateur **sans identité** (confirmation active : aucun e-mail ne part), soit par
  `user_already_exists` : les deux mènent à l'écran du code, comme une inscription neuve. Cet
  écran ne dit pas qu'un code est parti, et indique à tous que pour une adresse déjà inscrite
  aucun code n'arrivera, avec les liens vers la connexion et « Mot de passe oublié » : le
  titulaire n'attend pas en vain, et personne n'apprend si l'adresse est inscrite. Ne jamais
  réintroduire un contrôle `identities.isEmpty`. `email_not_confirmed` (et donc le bouton « Recevoir un code de confirmation »)
  ne révèle rien : GoTrue vérifie le mot de passe **avant** la confirmation, si bien qu'un mauvais
  mot de passe sur un compte non confirmé répond `invalid_credentials`, comme un compte inconnu
  (vérifié sur le serveur local).
- **Passerelle d'auth (`worker/authgate/`)** : l'app ne suffit pas, l'API publique de GoTrue
  trahit elle-même les comptes. L'inscription renvoie un utilisateur sans identité pour un compte
  confirmé ; deux demandes en moins d'une minute (`GOTRUE_SMTP_MAX_FREQUENCY`) donnent 429 pour un
  compte et 200 pour une adresse inconnue ; la durée trahit l'envoi SMTP et le bcrypt du mot de
  passe ; `PUT /user` répond `email_exists` à qui vise l'adresse d'un autre. Caddy confie donc au
  worker `POST /signup`, `/recover`, `/resend`, `/token` et `PUT /user` (ce dernier après la
  garde ci-dessous), qu'il relaie à GoTrue :
  - **inscription, mot de passe oublié, renvoi** : toujours 200 `{}`, toujours après 1,5 s, que
    GoTrue ait réussi, limité, échoué ou pas encore fini (sa requête continue, l'e-mail part ;
    64 au plus en route, au-delà la même réponse sans relais, contre les rafales).
    Seules passent tout de suite les erreurs de saisie, rendues avant toute recherche de compte :
    mot de passe faible, adresse mal formée, captcha, limite **par IP** ; un 429 inconnu est masqué ;
  - **`/token`** : réponse de GoTrue intacte, jamais avant 0,8 s. GoTrue lit `grant_type` dans
    la requête **et** dans un corps de formulaire : seul un rafraîchissement en JSON y échappe ;
  - **`PUT /user`** : tout changement d'adresse est refusé (`email_change_disabled`) sans
    interroger GoTrue — clé `email` en toute casse, JSON illisible compris. L'app ne change que
    le mot de passe ; un futur écran de changement d'adresse devra d'abord masquer `email_exists`.
  Lien magique coupé (`GOTRUE_EXTERNAL_EMAIL_MAGIC_LINK_ENABLED=false`), et Caddy répond lui-même
  à `/otp` : GoTrue y cherche le compte **avant** de lire ce réglage. Contrepartie : si le worker
  tombe, ces routes échouent ; et qui dépasse une limite voit « code envoyé » sans rien recevoir.
  Éprouvé par `check.dart` (répétition), à travers Caddy.
- **Garde des jetons d'assistant IA (`worker/authgate/guard.go`)** : le jeton qu'un assistant
  obtient du serveur OAuth de GoTrue est un jeton d'utilisateur, plus un claim `client_id`. Sur les
  routes de compte, il pourrait lire l'adresse, changer le mot de passe, lier ou délier une
  identité, fermer toutes les sessions ou **accorder un autre accès** au nom du membre — aucun
  réglage de GoTrue ne l'empêche. Caddy confie donc au worker, toutes méthodes, `/user*`
  (identités et accès accordés compris), `/logout*`, `/factors*`, `/reauthenticate*` et
  `/oauth/authorizations*` : la garde y refuse tout jeton porteur de `client_id` (403
  `assistant_forbidden`) et relaie le reste tel quel, `X-Forwarded-For` compris ; `PUT /user` passe
  **ensuite** par la passerelle. Le jeton est lu sans vérifier sa signature : on ne fait que
  refuser davantage. Les autres portes (PostgREST, temps réel) et le serveur OAuth :
  [`mcp-architecture.md`](./mcp-architecture.md).
- **Codes valables 15 minutes** (`otp_expiry = 900`) : un code de réinitialisation deviné donne
  le compte, et la seule limite est `token_verifications` (30 essais / 5 min / IP). La
  réinitialisation vérifie **toujours** le code, même avec une session ouverte.
- **Changer de mot de passe exige une session récente** (`secure_password_change`,
  `GOTRUE_SECURITY_UPDATE_PASSWORD_REQUIRE_REAUTHENTICATION`) : au-delà de 24 h, GoTrue réclame un
  code envoyé par e-mail (gabarit `reauthentication`). L'app n'en a pas besoin : son seul
  changement de mot de passe suit la réinitialisation, dont le code ouvre une session neuve.
  Mais un jeton de session volé ne suffit plus à prendre le compte par l'API (vérifié sur le
  serveur local : session vieillie de 25 h → `reauthentication_needed`).
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
  description), qui peut la nommer. La politique de confidentialité le dit.
- **L'écran le dit avant, et propose d'effacer** : le dialogue de suppression liste ces rdv
  (`public.my_proposed_group_events`) et offre une case « Supprimer aussi ces rdv »
  (`public.delete_my_proposed_group_events`). C'est le dernier moment où c'est possible : le
  compte supprimé, plus personne n'a le droit de les effacer. Les deux fonctions sont
  `SECURITY INVOKER` — la RLS des rdv dit déjà qui peut lire et qui peut supprimer ; une fonction
  `SECURITY DEFINER` devrait refaire ces contrôles et pourrait se tromper. Les occurrences
  modifiées d'une série sont écartées de la liste : elles appartiennent à une série déjà comptée,
  et la supprimer les emporte. **Seuls les groupes qui survivent comptent** : un groupe où l'on
  est seul est supprimé avec son agenda et ses rdv (`keep_group_alive`), donc rien n'y reste —
  l'annoncer serait faux, et proposer de l'effacer, inutile.
- **Compte effacé hors de la RPC** (interface d'administration de Supabase) : seule la cascade
  joue ; le trigger `private.keep_group_alive` transmet alors ou supprime ses groupes
  ([`groups-architecture.md`](./groups-architecture.md)).
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
| `supabase/migrations/20260923000000_left_behind_events.sql` · `tests/left_behind_events_test.sql` | ce que la suppression laisse au groupe : le lister, l'effacer |
| `supabase/templates/*.html` | Gabarits bilingues |
| `worker/authgate/gate.go` · `guard.go` | Passerelle (réponses et délais identiques, compte ou pas) ; garde des jetons d'assistant sur les routes de compte |

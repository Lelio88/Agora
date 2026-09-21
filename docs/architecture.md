# Architecture d'Agora

Agora met en commun les agendas de plusieurs personnes : chacun garde le sien, que l'app saisit
ou importe (lien iCal), et le partage dans des groupes au niveau de détail qu'il choisit. Un bot
Discord, réglé depuis l'app, publie l'agenda d'un groupe et répond aux commandes.

La règle de vie privée vit **dans la base** (RLS + une fonction de résolution unique), pas dans
les clients : l'app et le worker lisent le même résultat, déjà masqué. Ce document est l'index ;
le périmètre et l'ordre de construction sont dans [`roadmap.md`](./roadmap.md).

## 1. Vue d'ensemble

```
┌──────────────────────────┐        ┌──────────────────────────────┐
│ App Flutter (Android+web)│        │ Discord                      │
│ features → supabase_flutter│      │ salons, commandes /agenda …  │
└────────────┬─────────────┘        └───────▲──────────────┬───────┘
             │ HTTPS : Auth (JWT), RPC,      │ REST          │ interactions
             │ PostgREST                     │ (messages)    │ HTTP signées
┌────────────▼─────────────┐        ┌───────┴──────────────▼───────┐
│ Supabase auto-hébergé    │        │ Worker Go                    │
│ GoTrue · PostgREST       │        │ iCal · RRULE · bot Discord   │
└────────────┬─────────────┘        └───────┬──────────────┬───────┘
             │ SQL (rôle authenticated,     │ pgx direct    │ HTTPS sortant
             │ RLS appliquée)               │               ▼
┌────────────▼──────────────────────────────▼───┐   flux iCal des utilisateurs
│ Postgres                                       │   (Google, Outlook, iCloud)
│  public  : tables métier, RLS, RPC             │
│  private : URL iCal, helpers RLS,              │
│            resolve_group_agenda (visibilité)   │
└────────────────────────────────────────────────┘
```

| Dossier | Rôle |
|---|---|
| `app/` | App Flutter, feature-first sous `lib/src/features/<f>/{domain,data,application,presentation}` |
| `supabase/` | `config.toml` (pile locale, ports 553xx), `migrations/`, `tests/` (pgTAP) |
| `worker/` | Service Go : synchro iCal, dépliage des récurrences, bot Discord |
| `docs/` | Cette architecture, son annexe [`auth-architecture.md`](./auth-architecture.md) (comptes) et la feuille de route |

### Infrastructure partagée

| Package | Rôle |
|---|---|
| `app/lib/src/composition_root.dart` | Seul point (avec `main.dart`) qui importe les couches `data/` ; `prodOverrides` branche chaque `*RepositoryProvider` |
| `app/lib/src/supabase/` | `SupabaseConfig` : URL + clé lues au build, sans valeur par défaut ; `http` limité aux hôtes locaux |
| `app/lib/src/exceptions/` | `AppException` scellée (switch exhaustif des messages) ; `AsyncErrorLogger` transmet toute erreur de provider à `AppLogger` |
| `app/lib/src/logging/` | `AppLogger`, seule surface de journalisation (`dart:developer` par défaut) |
| `app/lib/src/routing/` | GoRouter, navigation par nom (`AppRoute` dans `app_route.dart`) ; `auth_redirect.dart` : règle de redirection pure, testée seule |
| `app/lib/src/device/` | `DeviceTimezone` : fuseau IANA de l'appareil (flutter_timezone), repli `Europe/Paris` |
| `app/lib/src/common_widgets/` | `SubmitButton` (désactivé pendant l'envoi), `FormErrorText`, `AsyncValueWidget` |
| `app/lib/src/localization/` | ARB : `app_fr.arb` de référence (avec descriptions), `app_en.arb` en traduction |
| `worker/internal/config/` | Configuration par variables d'environnement ; invalide = arrêt au démarrage |
| `worker/internal/httpx/` | Routes HTTP du worker (`/healthz`, puis interactions Discord) |

### Règles de couplage

| Couche (app) | Peut importer | Ne doit jamais importer |
|---|---|---|
| `domain/` | Dart pur, autres `domain/` | Flutter, Riverpod, Supabase, `data/` |
| `application/` | `domain/` | `data/`, `presentation/` |
| `data/` | `domain/`, `supabase_flutter` | `presentation/` |
| `presentation/` | `application/`, `domain/` | `data/` |
| feature A | `application/` d'une autre feature | ses `data/` ou `presentation/` |

Côté base, le worker lit les rdv d'autrui **uniquement** par `private.resolve_group_agenda` (§3).

## 2. Modèle de données

Migration de référence : `supabase/migrations/20260921120000_core_schema.sql`.

| Table | Contenu | Écrite par |
|---|---|---|
| `profiles` | nom affiché, avatar, fuseau IANA, langue (`fr`/`en`) | trigger d'inscription, puis l'utilisateur |
| `groups` | nom, description | `create_group()` ; admins pour renommer |
| `group_members` | rôle (`owner`/`admin`/`member`) **et `share_level`**, le partage choisi pour ce groupe | `create_group()`, `join_group()` ; chacun règle son `share_level` |
| `group_invites` | code de 8 caractères, expiration, nombre d'usages | `create_invite()` (tout membre) |
| `calendars` | agenda d'une personne **ou** d'un groupe ; `kind` = `native` ou `ics` ; `visibility` | l'utilisateur ; `add_ics_calendar()` |
| `private.calendar_feeds` | **URL iCal (secret)**, ETag, compteur d'échecs | `add_ics_calendar()`, puis le worker |
| `events` | rdv : horaires, `all_day`, `timezone`, `rrule`, `exdates`, `visibility` ; `source_uid` + `recurrence_id` pour l'iCal | l'utilisateur (natif) ; le worker (iCal) |
| `event_occurrences` | occurrences dépliées des rdv **récurrents** | le worker seul |

- **Inscription** : `private.handle_new_user` crée le profil et un agenda natif « Agenda ». Le nom
  vient des métadonnées du fournisseur (`display_name`, `full_name`, `global_name` Discord,
  `name`), puis « Membre ». Jamais de l'e-mail. La langue (`fr`/`en`) et le fuseau viennent des
  métadonnées `locale` et `timezone` s'ils sont valides, sinon `fr` et `Europe/Paris` : une valeur
  invalide ne fait jamais échouer une inscription.
- **Récurrences** : un rdv ponctuel se lit dans `events` ; un rdv récurrent se lit par ses
  `event_occurrences`, jamais par sa date d'origine. Le worker est la **seule** implémentation des
  RRULE (application, iCal, `/dispo` lisent tous le même dépliage). Une occurrence modifiée est un
  rdv ponctuel portant `recurrence_id`. Pas de fréquence infra-journalière (contrainte `CHECK`).
- **Clé de synchro iCal** : index unique partiel `(calendar_id, source_uid, recurrence_id)
  WHERE source_uid IS NOT NULL`. S'il n'était pas partiel, deux rdv natifs d'un même agenda
  entreraient en collision.

## 3. Règle de visibilité — le cœur métier

Pour un rdv **personnel** vu depuis un groupe, le niveau effectif est le **plus restrictif** de
trois réglages, avec l'ordre `details` < `busy` < `invisible` (d'où `greatest()` en SQL) :

| Réglage | Où | Valeurs |
|---|---|---|
| Partage du membre pour ce groupe | `group_members.share_level` | `details`, `busy` (défaut), `invisible` |
| Agenda | `calendars.visibility` | hérite (null), `busy`, `invisible` |
| Rdv | `events.visibility` | hérite (null), `busy`, `invisible` |

| Niveau effectif | Ce que voient les autres membres | `/dispo` |
|---|---|---|
| `details` | titre, lieu, identifiant du rdv | créneau pris |
| `busy` | un créneau « occupé » : **ni titre, ni lieu, ni identifiant** | créneau pris |
| `invisible` | rien | créneau **libre** |

- Le propriétaire voit toujours ses propres rdv en détail.
- Les rdv d'un **agenda de groupe** sont en détail pour tous les membres. Un agenda de groupe n'a
  pas de réglage de visibilité (contrainte `CHECK`).
- Agenda et rdv ne peuvent que **restreindre** : `details` y est interdit (contrainte `CHECK`).
- **Discord** : l'audience d'un salon déborde du groupe, donc les rdv personnels y sont plafonnés
  à `busy`. Les rdv de groupe restent en détail.

**Un seul chemin de sortie.** Le détail d'un rdv personnel n'atteint quelqu'un d'autre que son
propriétaire que par `private.resolve_group_agenda(groupe, lecteur, de, à, plafond)` :
- l'app l'appelle via `public.group_agenda()` (membre obligatoire, plage ≤ 93 jours, plafond
  `details`) ;
- le worker l'appelle en direct (lecteur `null`, plafond `busy` pour un salon Discord).

Les tables `events` et `event_occurrences` ne sont lisibles en direct que par le propriétaire,
ou par les membres pour un agenda de groupe. **Toute nouvelle façon de lire des rdv doit passer
par cette fonction**, sinon elle contourne les réglages de vie privée.

### Flux typique : `POST /rest/v1/rpc/group_agenda`

1. L'app envoie `{p_group_id, p_from, p_to}` avec le JWT de session et la clé publique.
2. PostgREST vérifie le JWT, passe en rôle `authenticated` et expose ses claims
   (`auth.uid()` = `sub`).
3. Postgres contrôle le droit `EXECUTE` sur `public.group_agenda` : `anon` est refusé (`42501`).
4. `group_agenda` (`SECURITY DEFINER`) vérifie l'appartenance au groupe (`not_a_member`,
   `42501`) et la plage (`invalid_range`, `22023`).
5. `private.resolve_group_agenda` joint membres → agendas → rdv, calcule le niveau effectif de
   chaque rdv, déplie les récurrents par `event_occurrences`, écarte les `invisible` et vide
   titre, lieu et identifiant des `busy`.
6. PostgREST sérialise les lignes en JSON : l'app ne reçoit jamais ce qu'elle ne doit pas voir.

## 4. Droits d'accès

- **Tout fermé, puis ouvert au plus juste** : la migration révoque tout à `anon` et `authenticated`,
  puis accorde colonne par colonne. `anon` n'a accès à rien.
- **Écritures sensibles par RPC `SECURITY DEFINER`** (`search_path = ''`) : `create_group`,
  `create_invite`, `join_group`, `add_ics_calendar`, `set_event_visibility`. Postgres donnant
  `EXECUTE` à `PUBLIC` sur toute nouvelle fonction, chaque fonction est révoquée puis accordée
  explicitement.
- **Pas d'escalade de rôle** : seul `share_level` est modifiable dans `group_members`. Le rôle ne
  change pas en direct.
- **Helpers RLS** dans `private` (`is_group_member`, `is_group_admin`, `is_group_owner`,
  `shares_group_with`, `can_read_calendar`, `can_add_event`, `can_edit_event`) : `SECURITY DEFINER`
  pour éviter la récursion RLS sur `group_members`. Le schéma `private` n'est pas exposé par l'API.
- **Anti-énumération** : un code d'invitation inconnu, expiré ou épuisé renvoie la même erreur
  (`invite_invalid`).
- Le propriétaire d'un groupe ne peut pas le quitter sans l'avoir transmis. Un admin exclut les
  simples membres.

## 5. Agendas iCal

- L'utilisateur colle l'adresse iCal secrète de son agenda (Google, Outlook, iCloud).
  `add_ics_calendar()` accepte `https://` et `webcal://` (réécrit en `https://`) et limite chaque
  personne à 10 flux.
- **L'URL est un secret** : elle vit dans `private.calendar_feeds`, qu'aucun client ne lit, même
  pas son propriétaire. L'app n'en affiche jamais la valeur.
- **Le worker protège contre le SSRF** : il résout le nom d'hôte et refuse toute adresse privée,
  de bouclage ou lien-local, **au moment de la connexion** (un contrôle de l'URL seule laisserait
  passer le DNS rebinding). Réponse bornée en taille et en durée ; `ETag`/`Last-Modified` évitent
  de retélécharger un flux inchangé.
- **La synchro n'écrase jamais `events.visibility`** : un rdv importé masqué reste masqué après
  relecture. L'upsert porte sur la clé `(calendar_id, source_uid, recurrence_id)`.
- L'état de synchro (`last_synced_at`, `sync_error`) est écrit dans `calendars`, lisible par le
  propriétaire.

## 6. Bot Discord

- **Interactions en HTTP** : Discord appelle le worker sur une URL d'interactions, avec une
  signature Ed25519 que le worker vérifie. Pas de connexion permanente à la passerelle. Les
  récaps et rappels sont envoyés par l'API REST avec le jeton du bot.
- **Réponses aux commandes visibles du seul demandeur** (`/agenda`, `/dispo`) : le demandeur doit
  avoir relié son compte Discord à Agora. On ne lui montre que ce que l'app lui montrerait.
- **Récaps et rappels publics** : rdv personnels plafonnés à `busy` (voir §3).
- **Liaison du compte Discord** : identité Supabase du fournisseur `discord`, obtenue en se
  connectant avec Discord ou par `linkIdentity` (`enable_manual_linking = true`). L'identifiant
  Discord se lit dans `auth.identities` : aucune table en double.
- **Réglage dans l'app** : salon, fréquence et heure du récap, délai des rappels, par groupe.

## 7. Application Flutter et comptes

Détail complet : [`auth-architecture.md`](./auth-architecture.md). Invariants :

- **E-mail + mot de passe confirmés par un code à 6 chiffres** (jamais un lien), valable
  15 minutes ; même principe pour le mot de passe oublié, qui vérifie **toujours** le code.
- **Anti-énumération** : compte inconnu, mauvais mot de passe et compte non confirmé avec un
  mauvais mot de passe donnent tous `invalid_credentials`. Seule l'inscription dit « un compte
  existe déjà » (choix assumé).
- **Le routeur navigue, pas l'écran**, après une connexion réussie ; `/reset-password` reste
  ouvert aux deux états ; `AuthScaffold(busy:)` neutralise l'écran pendant une action.
- **La langue du profil pilote l'app et les e-mails** (recopiée dans `raw_user_meta_data` par
  `private.sync_profile_locale`) ; **tous** les gabarits GoTrue sont surchargés, bilingues.

### Architecture de l'app

- Riverpod **sans génération de code** (providers écrits à la main), comme DewDrop : la
  génération de code entrait en conflit avec freezed 3. GoRouter avec routes nommées (`AppRoute`).
- **Composition root** : chaque `*RepositoryProvider` lève `UnimplementedError` tant qu'il n'est
  pas surchargé dans `prodOverrides`, et le test de démarrage monte l'app sous `prodOverrides`.
  Après toute modification de cette liste : hot **restart**, pas hot reload.
- **Configuration** : `--dart-define-from-file=config/<env>.json` (`SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`). Aucune valeur par défaut : une URL sans clé fait échouer le
  démarrage, au lieu des 401 muets d'une clé retombée sur celle du poste local.
- **Langues** : repli sur le français pour une langue d'appareil non prise en charge.
- **Android** : `INTERNET` déclarée dans le manifeste principal (le gabarit Flutter ne la met que
  dans les manifestes debug/profile) ; `applicationId` `app.agora`.

## 8. Patterns imposés

- **Migrations immuables** : une migration déjà appliquée en prod n'est **jamais** modifiée. Pour
  corriger, créer une nouvelle migration (`supabase migration new <slug>`). L'outil marque les
  fichiers joués et ne les rejoue pas : une retouche créerait une divergence silencieuse entre
  environnements.
- **Toute table** : RLS activée, `revoke all` puis GRANT par colonne, politiques nommées en
  français (« events: créer »).
- **Toute fonction** : `set search_path = ''`, noms qualifiés (`public.`, `private.`), `revoke
  execute ... from public, anon` puis accord explicite. Erreurs levées avec un message stable en
  anglais (`not_a_member`, `invite_invalid`), que l'app traduit.
- **Commentaire-doc en tête** de chaque fichier Dart (`library;`), package Go et migration :
  ce que fait le fichier, les choix non évidents, les invariants.

## 9. Stratégie de test

| Brique | Outil | Ce qui est couvert |
|---|---|---|
| Schéma | pgTAP (`supabase test db`) | `visibility_test.sql` : chaque niveau, le plafond Discord, la lecture directe interdite ; `groups_test.sql` : inscription, groupes, invitations, droits d'écriture, iCal ; `profile_test.sql` : langue et fuseau à l'inscription, fuseau validé, langue recopiée pour les e-mails |
| App | `flutter_test` | unités (règles de saisie, traduction des erreurs GoTrue, redirection, messages exhaustifs) ; parcours complets par `AgoraRobot` sous faux dépôts (connexion, inscription, code, mot de passe oublié, profil, langue) ; branchement de `prodOverrides` |
| Worker | `go test -race` | tests table-driven (`t.Run(tt.name, …)`) |

- **Scénario pgTAP canonique** : fixtures insérées en `postgres`, puis `set local role
  authenticated` + `set local request.jwt.claims = '{"sub": …}'` pour agir en tant qu'un membre, et
  `reset role` pour vérifier côté serveur. Chaque fichier tourne dans une transaction annulée.
- **Riverpod 3 relance les providers en échec** : un test d'erreur crée son conteneur avec
  `retry: (_, _) => null`, sinon `.future` ne se termine jamais.
- **Fakes plutôt que mocks** pour le code du projet (`test/helpers/fakes.dart`), et un robot
  (`test/helpers/agora_robot.dart`) qui monte l'app entière et porte tous les sélecteurs. Les
  écrans exposent des `ValueKey` (`AuthKeys`, `ProfileKeys`, `HomeKeys`) : les tests ne dépendent
  pas des libellés traduits.
- **Parcours réel sur le web** : `flutter build web --dart-define-from-file=config/local.json`,
  servir `build/web`, puis piloter avec Playwright. Flutter dessine sur un canvas ; cliquer
  `flt-semantics-placeholder` active l'arbre d'accessibilité, qui expose champs et boutons par
  leur libellé. Les codes se lisent dans Mailpit.

## 10. Hébergement et dépendances externes

| Service | Usage | Référence |
|---|---|---|
| Supabase auto-hébergé (Hetzner, serveur partagé) | Auth, API, Postgres ; `api.agora.heianenterprise.com` | recette d'Arpente, `../INFRASTRUCTURE.md` |
| Worker (conteneur) | iCal, récurrences, Discord ; **`mem_limit` obligatoire** (pic nocturne d'Ollama sur ce serveur) | `../INFRASTRUCTURE.md` |
| Brevo | e-mails d'authentification, `no-reply@heianenterprise.com` | `../brevo-email-guide.md` |
| Discord | application + bot : clé publique (signature), jeton du bot | portail développeurs Discord |
| Google / Discord OAuth | connexion (identité seule, sans accès à l'agenda) | console Google Cloud, portail Discord |

Secrets : coffre `../.agora-secrets/`, jamais dans ce dépôt, qui est public.

**`config.toml` ne règle que la pile locale.** Sur le serveur auto-hébergé, GoTrue lit les mêmes
réglages dans ses variables d'environnement (`GOTRUE_MAILER_AUTOCONFIRM=false`,
`GOTRUE_MAILER_OTP_EXP=900`, `GOTRUE_PASSWORD_MIN_LENGTH`,
`GOTRUE_PASSWORD_REQUIRED_CHARACTERS`, SMTP Brevo…). En prod s'ajoute un **CAPTCHA**
(`GOTRUE_SECURITY_CAPTCHA_*`, hCaptcha ou Turnstile) sur l'inscription, la connexion et la
réinitialisation : c'est lui, plus que la limite par IP, qui borne la force brute des codes
depuis de nombreuses adresses. Il charge
les gabarits **par URL** (`GOTRUE_MAILER_TEMPLATES_CONFIRMATION`, etc.), jamais depuis
`supabase/templates/`. Le déploiement doit donc servir ces fichiers et reporter chaque réglage :
un oubli ramène le comportement par défaut (lien au lieu de code, e-mail en anglais) sans erreur.

## 11. Anti-patterns à éviter

- ❌ Lire des rdv d'autrui ailleurs que par `resolve_group_agenda` (contourne la vie privée).
- ❌ Accorder une table à `authenticated` en entier « pour simplifier » : les droits se donnent
  colonne par colonne.
- ❌ Un index unique sur `source_uid` sans clause `WHERE source_uid IS NOT NULL` : un seul rdv
  natif possible par agenda.
- ❌ Déplier une RRULE ailleurs que dans le worker (deux implémentations finissent par diverger).
- ❌ Écrire `events.visibility` depuis la synchro iCal.
- ❌ Afficher, journaliser ou renvoyer une URL iCal.
- ❌ Contrôler le SSRF sur l'URL seule plutôt que sur l'adresse résolue au moment de la connexion.
- ❌ Donner une valeur par défaut à `SUPABASE_URL` ou à sa clé.
- ❌ Ajouter un flux d'e-mail GoTrue sans son gabarit bilingue : il partirait en anglais.
- ❌ Naviguer soi-même après une connexion réussie : c'est au routeur de le faire, sur
  l'événement de session.
- ❌ Écrire l'état d'un contrôleur après un `await` sans vérifier `ref.mounted`.

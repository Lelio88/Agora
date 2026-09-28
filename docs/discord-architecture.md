# Bot Discord

Annexe de [`architecture.md`](./architecture.md) §6. Le bot répond à quatre commandes et publie,
dans le salon relié à un groupe, un récap de l'agenda et des rappels avant les rdv du groupe.
Tout passe par le worker Go ; il n'y a aucune connexion permanente à la passerelle Discord.

## Flux

```
Discord ──interaction signée (HTTP POST)──► Caddy /discord/interactions ──► worker :8080
   ▲                                                                          │
   └───────── API REST (jeton du bot) : récaps, rappels ◄─────────────────────┤
                                                                               ▼
                                              Postgres : private.discord_* (rôle agora_worker)
```

- **Interactions** (`worker/discord/handler.go`). Le worker vérifie la signature Ed25519
  (horodatage frais de cinq minutes) **avant** toute lecture en base, et rend 401 sinon :
  c'est à ce comportement que Discord valide l'URL d'interactions. Sans
  `AGORA_DISCORD_PUBLIC_KEY`, la route n'est pas montée.
- **Réponses** : toujours éphémères (flag 64, visibles du seul demandeur), et
  `allowed_mentions` vide, si bien qu'un titre contenant « @everyone » ne notifie personne. Le
  texte libre (titres, lieux, noms) est neutralisé : la mise en forme Markdown est échappée et
  les sauts de ligne sont retirés. Un message est coupé sous la limite des 2 000 caractères.
- **Publication** (`worker/discord/publish.go`) : toutes les minutes, le worker réclame les
  rappels puis les récaps dus. **Réclamer** veut dire marquer comme envoyé avant l'envoi : une
  panne de Discord perd un message plutôt que d'en publier deux. Sans
  `AGORA_DISCORD_BOT_TOKEN`, rien n'est publié.
- **Langue** : chaque réponse est rédigée dans la langue du client Discord du demandeur. Une
  publication utilise la langue et le fuseau de la personne qui a relié le salon, figés au
  moment de la liaison.

## Commandes

Les noms de base sont en français ; l'anglais passe par `name_localizations`. Les commandes sont
inscrites par `worker register-commands` (voir [Mise en service](#mise-en-service)).

| Commande | Où | Ce qu'elle fait |
|---|---|---|
| `/relier code` (`/link`) | salon d'un serveur, droit « Gérer les salons » | relie le salon au groupe du code |
| `/delier` (`/unlink`) | idem | délie le salon |
| `/agenda [jours]` | partout | dans un salon relié : l'agenda du groupe **vu par le demandeur** (il doit en être membre). Ailleurs : son propre agenda. 7 jours par défaut, 31 au plus |
| `/dispo duree [jours debut fin weekend]` (`/free`) | salon relié | créneaux libres pour tous les membres du groupe |

- **Qui peut relier** : Discord ne propose `/relier` qu'aux personnes qui peuvent gérer le
  salon (`default_member_permissions`). Un serveur peut modifier ce réglage, donc le worker
  relit le droit (administrateur ou « Gérer les salons ») dans le champ `member.permissions` de
  l'interaction. La base exige en plus que le compte Discord soit relié à un **admin du groupe**
  désigné par le code : un code qui fuit ne suffit pas. `/delier` a les mêmes exigences : un
  modérateur du serveur étranger au groupe ne coupe pas ses publications, mais il peut toujours
  retirer le bot du serveur.
- **`/dispo`** reprend `app/lib/src/features/groups/domain/free_slots.dart` dans
  `worker/discord/slots.go`. Le code Dart fait foi, et les deux versions partagent leurs cas de
  test. Tous les membres sont requis. Un membre qui ne partage rien paraît libre, et la réponse
  le rappelle.

## Liaisons

- **Compte Discord ↔ compte Agora** : c'est une identité GoTrue du fournisseur `discord`,
  obtenue par `linkIdentity` (OAuth, scope `identify`) depuis Profil → Discord. Il n'y a aucune
  table en double : `private.discord_user(id)` lit `auth.identities`. Au retour de l'OAuth,
  Android reçoit `app.agora://login-callback` (intent-filter du manifeste) et le web revient sur
  sa propre page. Les deux adresses doivent figurer dans `ADDITIONAL_REDIRECT_URLS`. Un compte
  Discord déjà relié ailleurs produit `DiscordAlreadyLinkedException`.
- **Salon ↔ groupe** : un admin crée un code (`create_discord_link_code`, 10 minutes, usage
  unique ; un nouveau code remplace le précédent), puis tape `/relier CODE` dans le salon. Un
  salon sert un seul groupe (`channel_id` unique), et un groupe publie dans un seul salon (clé
  primaire `group_id`). Relier un autre salon au même groupe remplace l'ancien.
- **Limite connue** : GoTrue n'a pas de mode « liaison seulement ». Une fois le fournisseur
  activé, un appel forgé à `/auth/v1/authorize?provider=discord` peut créer un compte Agora par
  Discord, sans passer par l'écran d'inscription ni par son CAPTCHA. Ce compte est ordinaire
  (adresse e-mail vérifiée par Discord, profil créé par le trigger d'inscription). L'app n'en
  propose le chemin nulle part.

## Données

Migration : `supabase/migrations/20260928100000_discord_bot.sql`.

| Objet | Contenu | Écrit par |
|---|---|---|
| `public.discord_channels` | groupe, serveur, salon (et son nom à la liaison), fuseau et langue des publications, fréquence (`off`/`daily`/`weekly`), jour et heure du récap, délai de rappel (15, 60 ou 1 440 min, ou aucun) | `/relier` (worker) ; réglages et suppression par les admins (RLS) ; lecture par les membres |
| `private.discord_link_codes` | codes de liaison | `create_discord_link_code` ; consommés par `/relier` |
| `private.discord_reminders_sent` | journal des rappels envoyés `(event_id, starts_at)`, purgé après deux jours | `discord_claim_reminders` |

| Fonction (`agora_worker` seul) | Rôle |
|---|---|
| `discord_user(discord_id)` | compte Agora relié, avec son fuseau et sa langue |
| `discord_link_channel` / `discord_unlink_channel` / `discord_channel_group` | liaison du salon |
| `discord_group_agenda(groupe, lecteur, de, à)` | `resolve_group_agenda` avec lecteur = demandeur et plafond `details` ; le demandeur doit être membre |
| `discord_group_members` | membres du groupe, pour `/dispo` |
| `discord_personal_agenda` | ce que `my_agenda` rendrait au demandeur : ses agendas et ceux de ses groupes, sans les agendas qu'il a masqués |
| `discord_claim_recaps` / `discord_recap_agenda` | récaps dus, et leur contenu : `resolve_group_agenda` **sans lecteur, plafond `busy`**, huit jours au plus |
| `discord_claim_reminders` | rappels dus : rdv **du groupe** seulement, jamais une journée entière |

## Vie privée

- **Une réponse à une commande = ce que l'app montrerait au demandeur**, sans rien de plus.
- **Une publication dans un salon** : les rdv personnels sont plafonnés à « occupé », sans
  titre ni lieu. Les rdv du groupe restent en détail. Un salon peut compter des personnes hors du
  groupe, et l'écran de réglage le signale en permanence.
- **Rappels** : jamais un rdv personnel.
- Un récap en retard de plus de six heures n'est plus envoyé : un redémarrage du worker, ou un
  réglage modifié le soir, ne publie pas celui du matin.

Tests : `supabase/tests/discord_test.sql` (liaison, lectures au nom du demandeur, plafond des
récaps, rappels uniques, droits de l'app) ; `worker/discord/*_test.go` (commandes sur faux
stockage, créneaux, publication, inscription des commandes, `PgStore` en `-tags integration`) ;
`app/test/src/features/discord/` (parcours du profil et de l'écran du salon).

## Mise en service

1. Portail Discord : créer l'application, puis relever l'**Application ID** et la **Public Key**.
   Dans l'onglet OAuth2, relever le Client ID et le Client Secret, et déclarer la redirection
   `https://api.agora.heianenterprise.com/auth/v1/callback`. Dans l'onglet Bot, relever le jeton.
2. Coffre `../.agora-secrets/`, puis le `.env` du serveur : `DISCORD_OAUTH_ENABLED=true`,
   `DISCORD_OAUTH_CLIENT_ID`, `DISCORD_OAUTH_SECRET`, `DISCORD_PUBLIC_KEY`,
   `DISCORD_APPLICATION_ID`, `DISCORD_BOT_TOKEN`. Y ajouter aussi
   `ADDITIONAL_REDIRECT_URLS=https://agora.heianenterprise.com,app.agora://login-callback`.
3. Relancer GoTrue et le worker (`docker compose up -d auth worker`), puis inscrire les
   commandes : `docker exec agora_worker /worker register-commands`.
4. Portail Discord : **Interactions Endpoint URL** =
   `https://api.agora.heianenterprise.com/discord/interactions`. Discord l'accepte quand le
   worker répond au ping et refuse les appels mal signés.
5. Variable du dépôt GitHub `AGORA_DISCORD_APPLICATION_ID`, et la même clé dans
   `app/config/prod.json` : l'app propose alors d'inviter le bot.

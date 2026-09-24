# Mise en ligne — annexe d'architecture

Annexe de [`architecture.md`](./architecture.md) §10. Elle décrit la pile de production, sa
première installation, la chaîne de déploiement et sa répétition sur un poste de travail. La
carte du serveur partagé (IP, autres projets, sauvegardes) vit hors dépôt, dans
`../INFRASTRUCTURE.md`.

## Vue d'ensemble

```
 Navigateur, app Android
        │ HTTPS
┌───────▼──────────── Caddy de l'hôte (systemd, seul à écouter 80/443) ─────────────┐
│ agora.heianenterprise.com            api.agora.heianenterprise.com               │
│   /         → /opt/agora/web           /auth/v1/*      → 127.0.0.1:9401 GoTrue    │
│   /email/*  → /opt/agora/email         /rest/v1/*      → 127.0.0.1:9402 PostgREST │
│               (gabarits pour GoTrue)   /realtime/v1/*  → 127.0.0.1:9403 Realtime  │
│                                        CORS : Caddy tient le rôle de Kong         │
└──────────────────────────────────────────────┬────────────────────────────────────┘
                                               │ boucle locale uniquement
┌── docker compose « agora » (/opt/agora) ─────▼────────────────────────────────────┐
│ agora_auth ─────┐   agora_rest ─────┐   agora_realtime ─────┐                     │
│ agora_worker ───┴───────────────────┴──► agora_db (supabase/postgres, volume)     │
│   :9404 /healthz                         ne publie aucun port                     │
└───────────────────────────────────────────────────────────────────────────────────┘
  GoTrue ── SMTP 587 (STARTTLS) ──► Brevo          worker ── HTTPS ──► flux iCal
```

## Fichiers

| Fichier | Rôle |
|---|---|
| `deploy/docker-compose.prod.yml` | la pile : Postgres, GoTrue, PostgREST, Realtime, worker ; plafonds mémoire ; traduction de `config.toml` en `GOTRUE_*` |
| `deploy/init/zzz-roles.sql` | mots de passe des rôles internes et schéma `_realtime`, joués à la création du volume |
| `deploy/migrate.sh` | applique `supabase/migrations/` (une transaction par migration, suivi dans la table du CLI), pose le mot de passe du worker, recharge PostgREST |
| `deploy/caddy/agora.caddy` | les deux vhosts, autonomes (importés par le Caddyfile de l'hôte) |
| `deploy/production.env.example` · `gen-secrets.sh` | gabarit du `.env` ; secrets aléatoires et clés JWT `anon`/`service_role` signées avec `openssl` |
| `app/web/captcha.html` | la page du widget Turnstile, servie par le domaine d'Agora (web et Android) |
| `deploy/bootstrap-server.sh` | première installation d'un serveur, idempotente |
| `deploy/rehearsal/` | répétition locale : `rehearse.sh`, override (Mailpit, Caddy), `check.dart` |
| `worker/Dockerfile` | image distroless du worker, dépendances vendorisées |
| `.github/workflows/deploy.yml` | tests, image du worker (GHCR), app web, puis déploiement par SSH |

## Choix non évidents et pièges

- **Pas de Kong** (ni Studio, Storage, pg-meta) : Caddy route les préfixes du client Supabase.
  Mais Kong gérait aussi le **CORS** : GoTrue ignore l'en-tête `apikey`, et sans réponse de
  Caddy au contrôle préalable, le navigateur bloque tout. Caddy répond 204 aux `OPTIONS` et
  **remplace** (`defer`) l'origine qu'émet GoTrue : deux valeurs font refuser la réponse.
  L'origine autorisée est la seule app web.
- **`X-Supabase-Api-Version` doit être exposé** (`Access-Control-Expose-Headers`) : un
  navigateur ne lit que les en-têtes exposés, et sans celui-ci le client Supabase croit parler à
  une ancienne API, cherche `error_code` dans un corps qui dit `code`, et rend une erreur sans
  code : l'app affiche « une erreur est survenue » pour **toutes** les erreurs d'authentification
  (mot de passe faux, adresse non confirmée, limite atteinte). Kong l'exposait ; la répétition le
  vérifie désormais.
- **Realtime lit son tenant dans le premier segment du `Host`** : Caddy envoie
  `realtime-dev.agora`. **`handle_path`**, jamais `handle` + `uri strip_prefix` (Caddy exécute
  `rewrite` avant `uri`).
- **Mots de passe des rôles internes posés une fois**, à la création du volume : l'image ne
  propage pas `POSTGRES_PASSWORD`, et son rôle `postgres` n'est pas superutilisateur. Changer
  `POSTGRES_PASSWORD` ensuite ne change rien aux rôles ; il faut les modifier en `supabase_admin`.
- **Le schéma s'applique après le premier démarrage de GoTrue**, qui crée `auth.users`. Une
  migration appliquée n'est jamais rejouée ni modifiée ; `supabase migration list --db-url` lit
  le même suivi.
- **Réglages GoTrue = `config.toml` traduit**, un réglage oublié ramenant le défaut sans erreur.
  Trois écarts voulus : 30 e-mails par heure pour toute l'instance (2 en local), une minute entre
  deux e-mails à une même adresse, et des limites **par client** lues dans `X-Forwarded-For`
  (derrière Caddy, sinon, tout le monde partage la même limite).
- **GoTrue refuse l'authentification SMTP en clair** : Brevo passe par STARTTLS ; la répétition,
  avec Mailpit sans TLS, envoie sans authentification.
- **Gabarits d'e-mail lus par URL** (`/email/`) ; un échec de lecture ramène en silence le
  gabarit anglais de GoTrue : la répétition vérifie le corps du message, pas seulement le sujet.
- **CAPTCHA (Cloudflare Turnstile)** : l'app obtient un jeton avant toute inscription,
  connexion, réinitialisation ou renvoi de code, et GoTrue le vérifie
  (`GOTRUE_SECURITY_CAPTCHA_*`). Sans lui, le quota d'e-mails (30 par heure) vaut pour **toute
  l'instance** : n'importe qui pourrait l'épuiser et priver les autres de leur code.
  **Les deux côtés vont ensemble** : activer le serveur avant que l'app n'envoie de jeton
  casserait inscription et connexion ; la clé de site absente du build produit l'inverse. Ordre
  sûr : déployer l'app d'abord, poser `CAPTCHA_ENABLED=true` ensuite.
  La page du widget (`app/web/captcha.html`) est servie par le domaine d'Agora, seul autorisé
  par la clé — le web l'affiche dans une iframe, Android dans une vue web.
- **Mémoire** (serveur partagé, pic nocturne d'Ollama) : chaque service a sa `mem_limit`, ~1 Go
  de plafonds pour ~350 Mo mesurés en répétition (Realtime ~190, Postgres ~130).
- **Images épinglées** sur celles de la pile locale, contre lesquelles tournent les tests.
- **Clés JWT valables 10 ans** : révoquer = nouveau `JWT_SECRET`, nouvelles clés, secret GitHub
  `AGORA_ANON_KEY` mis à jour, app web et Android reconstruites.
- **L'app web est remplacée en dernier**, par bascule de dossier, une fois les services sondés ;
  servie en `no-cache` (fichiers Flutter non hachés).
- **Les pages légales voyagent avec l'app** : `app/web/legal/` est recopié tel quel par
  `flutter build web`, donc publié sur `/legal/confidentialite.html`, `/legal/mentions-legales.html`
  et `/legal/conditions.html` sans rien ajouter à Caddy. Ce sont les adresses à donner à la fiche
  Play Store ; elles ne doivent donc plus changer.

## Première installation

1. DNS (zone Cloudflare, nuage gris) : `agora` et `api.agora` vers le serveur.
2. Vérifier que Caddy est en 2.7.5 ou plus récent (`caddy version`) : en deçà, un client peut
   forger son `X-Forwarded-For` et contourner les limites par client de GoTrue.
3. `scp -r deploy root@<serveur>:/tmp/agora-deploy` puis
   `ssh root@<serveur> sh /tmp/agora-deploy/bootstrap-server.sh` : `/opt/agora`, `.env` aux
   secrets aléatoires, ports 9401-9404 vérifiés libres, vhost importé, base déclarée à la
   sauvegarde nocturne.
4. Dans `/opt/agora/.env` : `SMTP_USER`, `SMTP_PASS` (clé SMTP Brevo propre à Agora,
   `../brevo-email-guide.md`). Copier ce `.env` dans le coffre (`.agora-secrets/supabase.env`).
5. Secrets GitHub du dépôt : `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`, `AGORA_ANON_KEY`.
6. `git push origin main:release`, puis s'inscrire sur l'app web : le code doit arriver.
7. Consigner le service dans `../INFRASTRUCTURE.md` ; vérifier que le rapatriement des
   sauvegardes récupère les dumps d'Agora.

## Mettre en ligne, revenir en arrière

- **Mettre en ligne** : `git push origin main:release` (ou lancer le workflow à la main).
  `verify` → image et app web → déploiement : base et GoTrue, `migrate.sh`, reste de la pile,
  sonde, bascule de l'app web, `AGORA_TAG` mémorisé dans le `.env`.
- **Revenir en arrière** : relancer le workflow sur un commit antérieur, ou sur le serveur
  `AGORA_TAG=<sha> docker compose up -d worker`. Le schéma ne recule pas : une migration fautive
  se corrige par une nouvelle migration.

## Répéter en local

`sh deploy/rehearsal/rehearse.sh` monte la pile de production telle quelle (secrets jetables,
dans `deploy/rehearsal/.work/`), applique les migrations deux fois, puis `check.dart` parcourt la
pile à travers Caddy : CORS, inscription avec le code reçu (gabarit français lu par URL), REST,
Realtime, dépliage d'une série par le worker, règle de vie privée, suppression de compte. Environ
une minute, sans toucher à la pile de développement. **À relancer avant tout changement de ce
qui est décrit ici.** `--keep` laisse la pile en marche pour y essayer l'app web dans un
navigateur (`web-config.json` fourni) ; `--down` la démonte.

## Avant l'ouverture au public

CAPTCHA dans l'app (il conditionne l'ouverture : sans lui, le quota d'e-mails s'épuise depuis
n'importe où), pages légales, fiche Play Store et liens d'application Android
(`assetlinks.json`) pour les invitations, identifiants OAuth Google et Discord, bot Discord
(étape 8) : voir [`roadmap.md`](./roadmap.md).

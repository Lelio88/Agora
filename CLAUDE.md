# Agora — Contexte d'Opération et Garde-Fous Agentiques

Résolvez les problèmes sans introduire de régression ni de dette technique architecturale.

## I. Finalité

**Application** : Agora — agendas partagés en groupe (Android + web), avec un bot Discord.
**Objectif métier** : chacun garde son agenda (saisi dans l'app ou importé par lien iCal) et le partage dans des groupes au niveau de détail qu'il choisit ; le groupe voit qui est pris, trouve des créneaux communs, et un bot Discord réglé depuis l'app publie l'agenda. Public visé : tout public, via le Play Store.

## II. Architecture

**Modèle** : monorepo à trois briques. Une app Flutter feature-first (Clean Architecture), un backend Supabase où la **règle de vie privée vit en SQL** (RLS + une fonction de résolution unique), et un worker Go (iCal, récurrences, Discord) branché en direct sur Postgres.

**Détails complets** (modèle de données, règle de visibilité, flux d'une requête, droits, iCal, Discord, tests, anti-patterns) : voir [`docs/architecture.md`](./docs/architecture.md), et ses annexes [`auth`](./docs/auth-architecture.md), [`calendar`](./docs/calendar-architecture.md) et [`groups`](./docs/groups-architecture.md). Périmètre et étapes : [`docs/roadmap.md`](./docs/roadmap.md).

Topologie rapide :
- `app/lib/src/features/<f>/{domain,data,application,presentation}/` — les features.
- `app/lib/src/` — `composition_root.dart`, `app.dart`, `routing/`, `supabase/`, `exceptions/`, `logging/`, `localization/` (ARB).
- `supabase/migrations/` — schéma, RLS, RPC ; `supabase/tests/` — pgTAP ; `config.toml` — pile locale sur les ports 553xx.
- `worker/cmd/worker/` — le binaire ; `worker/internal/{config,database,httpx}/` ; `worker/recurrence/` — dépliage des séries (`Expand` pur, `Service`, `PgStore`, `Listen`).

## III. Pile Technologique

*Versions contraintes par `app/pubspec.yaml` et `worker/go.mod`. N'introduisez aucune dépendance alternative sans approbation.*

- **App** : Dart ^3.13 / Flutter stable ; `flutter_riverpod` ^3.4 **sans codegen**, `go_router` ^18, `supabase_flutter` ^2.17, `flutter_timezone` ^5.1, `kalender` ^0.31 (vues d'agenda ; 0.x : API mouvante, garder la version mineure), `flutter_localizations` + `intl`.
- **Backend** : Supabase (Postgres 17, GoTrue, PostgREST), auto-hébergé sur Hetzner en prod ; CLI ≥ 2.114 en local.
- **Worker** : Go 1.26 ; `pgx/v5` (Postgres en direct, rôle `agora_worker`), `teambition/rrule-go` (RRULE), `time/tzdata` embarqué.
- **Auth** : e-mail (SMTP Brevo), Google, Discord ; liaison manuelle d'identités activée.
- **Android** : `applicationId` **`app.agora`**, figé dès le premier envoi au Play Store.

## IV. Garde-Fous non négociables

1. **Vie privée : un seul chemin de sortie.** Le détail d'un rdv d'autrui ne se lit que via `private.resolve_group_agenda`, appelée par `group_agenda()` ou par le worker. Niveau effectif : le plus restrictif de `share_level`, `calendars.visibility` et `events.visibility`. Discord plafonne les rdv perso à `busy`. Toute évolution de la règle ajoute son test pgTAP.
2. **Droits Supabase fermés par défaut** : RLS **et** GRANT par colonne à `authenticated` (rien à `anon`). Toute fonction nouvelle : `revoke execute ... from public, anon`, puis accord explicite. `SECURITY DEFINER` toujours avec `search_path = ''`. Les helpers RLS vivent dans le schéma `private`.
3. **Migrations immuables** : une migration déjà appliquée en prod n'est **jamais** modifiée. Corriger = nouvelle migration.
4. **Secrets hors du dépôt, qui est public** : URL et clé de build dans `app/config/<env>.json` (gitignoré), secrets serveur dans `../.agora-secrets/`. Une URL iCal est un secret : ni affichée, ni journalisée, ni renvoyée par l'API.
5. **Le worker est l'unique implémentation des RRULE** : l'app lit l'agenda par `my_agenda()`, jamais la ligne maîtresse d'une série. Il n'écrit jamais `events.visibility` et contrôle le SSRF sur l'adresse **résolue** au moment de la connexion.
6. **Couplage Flutter** : `presentation` n'importe jamais `data`, et seule la composition root branche les implémentations. Les erreurs sont des `AppException` scellées ; seul `AppLogger` journalise.
7. **Deux langues** : toute chaîne d'interface naît dans `app_fr.arb` (avec sa description) et reçoit sa traduction dans `app_en.arb`, dans le même commit.

## V. Flux de Travail (Explore → Plan → Code → Verify)

1. **Exploration** — lire les fichiers adjacents pour calquer les patterns.
2. **Planification** — soumettre l'approche pour tout changement non trivial, a fortiori s'il touche la vie privée.
3. **TDD** — écrire le test en premier, vérifier qu'il échoue, **ne plus l'altérer**.
4. **Implémentation** — code minimal pour faire passer le test.
5. **Vérification** — `flutter analyze` (zéro issue) + `flutter test` ; `supabase test db` ; `go vet ./... && go test -race ./...`.

**Auto-documentation des packages** — tout nouveau fichier Dart (`library;`), package Go ou migration publie en tête un commentaire-doc : (1) ce qu'il fait, (2) les choix non évidents et leur motivation, (3) les invariants à préserver, (4) un exemple d'usage si l'API n'est pas évidente.

## VI. Commandes de Développement

```bash
supabase start                   # pile locale (API :55321, DB :55322) — Docker Desktop lancé
supabase db reset                # rejoue les migrations sur une base vierge
supabase test db                 # tests pgTAP (visibilité, groupes, droits)
bash supabase/checks/account_deletion_race.sh  # concurrence de la suppression de compte
supabase migration new <slug>    # nouvelle migration
cd app && flutter analyze && flutter test
cd app && flutter run -d chrome --web-port 58090 --dart-define-from-file=config/local.json  # copier local.json.example (liens d'invitation sur ce port)
cd worker && go vet ./... && go test -race ./...
AGORA_TEST_DATABASE_URL=postgresql://agora_worker:agora-worker-local@127.0.0.1:55322/postgres \
AGORA_TEST_ADMIN_URL=postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  go test -race -tags integration ./...   # PgStore et LISTEN contre la pile locale
AGORA_DATABASE_URL=postgresql://agora_worker:agora-worker-local@127.0.0.1:55322/postgres \
  go run ./cmd/worker              # déplie les séries ; AGORA_HTTP_ADDR (défaut :8080), /healthz
# E-mails locaux (codes de confirmation, réinitialisation) : Mailpit sur http://127.0.0.1:55324
```

## VII. Maintenance documentaire

**Règle d'or** : le diff du code et le diff de la doc correspondante sont dans **le même commit**.

| Modification | Fichier à mettre à jour |
|---|---|
| Table, colonne, RLS ou RPC | nouvelle migration (+ GRANT) + test pgTAP + `docs/architecture.md` §2-4 |
| Séries, exceptions, dépliage, agendas, écran d'agenda | `docs/calendar-architecture.md` + tests pgTAP (`agenda`, `calendars`, `series_move`) + tests Go de `worker/recurrence/` |
| Groupes, invitations, rôles, agenda de groupe | `docs/groups-architecture.md` + tests pgTAP (`groups`, `group_management`, `visibility`) |
| Règle de visibilité, ou nouvelle lecture de rdv | `docs/architecture.md` §3 + `supabase/tests/visibility_test.sql` |
| Commande ou réglage du bot Discord | `docs/architecture.md` §6 |
| Flux d'e-mail GoTrue ou réglage d'auth | gabarit FR+EN dans `supabase/templates/` + `config.toml` + variables `GOTRUE_*` du serveur + `docs/auth-architecture.md` |
| Nouvelle chaîne d'interface | `app_fr.arb` + `app_en.arb` |
| Étape de la feuille de route livrée | `docs/roadmap.md` (colonne État) |
| Mise en ligne, sous-domaine, service serveur | `../INFRASTRUCTURE.md` + `docs/architecture.md` §10 |
| Nouvel anti-pattern découvert | `docs/architecture.md` §11 |
| Changement de dépendance critique | Section III + `pubspec.yaml` / `go.mod` |

## VIII. Contexte de Session

- **Dernier focus** : étape 3 terminée — groupes (créer, inviter par code ou lien web, rejoindre avec le partage choisi, rôles, transmettre, quitter), agenda superposé par membre, accueil à deux onglets.
- **Focus immédiat** : étape 5 (import iCal) ou 6 (rdv de groupe) au choix ; Google et Discord attendent toujours les identifiants OAuth.

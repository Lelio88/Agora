# Import iCal — annexe d'architecture

Annexe de [`architecture.md`](./architecture.md) §5. Elle décrit comment un agenda importé par
lien iCal (Google, Outlook, iCloud…) entre dans Agora, se relit, et ce que l'app en montre.

**Deux invariants** : l'URL d'un flux est un secret (elle ouvre tout l'agenda d'origine) et ne
sort de la base que vers le worker — jamais vers l'app, un journal ou un message d'erreur ; un rdv
importé ne s'écrit que par la synchro, qui ne touche jamais `events.visibility`.

## Cycle de vie

```
app ── add_ics_calendar(nom, url) ──► calendars (kind = ics) + private.calendar_feeds (url)
                                              │ NOTIFY agora_ics (id de l'agenda)
worker ◄──────────────────────────────────────┘
  ics_due_feeds ──► flux dus (bail de 10 min)
  Fetch (https, garde SSRF, ≤ 5 Mio, 20 s, If-None-Match / If-Modified-Since)
  Parse (go-ical → lignes normalisées, 1 an en arrière + tout le futur, ≤ 5 000)
  ics_apply ──► upsert (calendar_id, source_uid, recurrence_id), suppression du reste,
                last_synced_at, ETag, prochaine relecture dans 30 min
  ics_record_unchanged (304) · ics_record_failure(code) (échec : 5 min × 2ⁿ, 24 h au plus)
app ◄── temps réel sur calendars : état de synchro ; sync_calendar_now : relecture immédiate
```

## En base (`20260922010000_ics_sync.sql`)

- **Le worker n'a aucun droit d'écriture direct** sur les agendas : il passe par quatre fonctions
  `SECURITY DEFINER` du schéma `private`, seules choses qu'il y atteint (`grant usage on schema
  private`, puis `execute` fonction par fonction). Il ne lit pas `calendar_feeds` : `ics_due_feeds`
  lui rend l'URL des seuls flux dus, en prenant un **bail** de 10 minutes (`next_sync_at`, `for
  update skip locked`) qui empêche deux instances de relire le même flux.
- **`ics_apply(agenda, lignes jsonb, etag, last_modified)`**, en une transaction : upsert des rdv
  ponctuels et lignes maîtresses (sans réécrire une ligne inchangée : `where … is distinct from`),
  repose des `exdates` du flux (le trigger `reset_series_exceptions` les viderait quand l'horaire
  change), upsert des occurrences modifiées rattachées à leur série du même flux (sans série : ignorées),
  suppression de ce qui a quitté le flux, puis `last_synced_at`, `sync_error = null`, validateurs
  HTTP, `next_sync_at = now() + 30 min`. Le trigger `check_event_series` exempte les agendas `ics`
  du contrôle « l'appelant peut modifier la série », qui échouerait toujours (personne n'écrit
  dans un tel agenda).
- **Un échec n'est qu'un code** (`ics_record_failure`) : `unreachable`, `timeout`, `not_found`,
  `forbidden`, `http_error`, `too_large`, `not_calendar`, `blocked_address`, `too_many_events` —
  tout autre texte est refusé (`invalid_sync_error`). Le texte d'une erreur réseau contiendrait
  l'URL. Le délai croît : 5 min × 2^(échecs), 24 h au plus.
- **`sync_calendar_now(agenda)`** : le propriétaire rend son flux dû tout de suite et réveille le
  worker ; sans effet si une relecture a été tentée dans la dernière minute.
- **`calendars` est publiée en temps réel** (sous RLS, comme `events`) : l'app voit
  `last_synced_at` et `sync_error` changer. `calendar_feeds` ne l'est jamais.

## Le worker relit (Go, `worker/ics/`)

- **`Feed`** ne s'imprime et ne se journalise que par son agenda (`String`, `Format`, `LogValue`) :
  un flux passé par mégarde à `fmt` ou `slog` ne livre pas son URL.
- **Garde SSRF** (`guard.go`) dans `net.Dialer.Control`, sur l'adresse **résolue** de chaque
  connexion, redirections comprises : refus des adresses privées, de bouclage, lien-local,
  multidiffusion, non spécifiées, CGNAT, plages de documentation, réservées, et des IPv6 qui
  embarquent une IPv4 (NAT64, 6to4, Teredo, `::ffff:`). `AGORA_ICS_ALLOW_PRIVATE_NETWORK=true` la
  lève, pour le développement et les tests seulement (journalisé en avertissement au démarrage).
- **Téléchargement** (`fetch.go`) : `https://` seul, pas de mandataire (le contrôle porterait sur
  lui), 3 redirections au plus et toutes en https, 20 s pour l'ensemble, corps ≤ 5 Mio (annoncé ou
  lu), `If-None-Match` / `If-Modified-Since` → 304 = inchangé. Chaque échec devient un code
  (`Failure`) ; l'arrêt du worker remonte l'erreur du contexte, sans noter d'échec.
- **Lecture** (`parse.go`, `emersion/go-ical`) : fenêtre d'un an en arrière + tout le futur (une
  série compte si une occurrence finit après le début de la fenêtre, cherchée par rrule-go sous un
  budget de temps — une règle impossible tourne jusqu'en 9999) ; ≤ 5 000 lignes ; textes tronqués
  aux bornes de la base (200 / 300 / 5 000 caractères), nettoyés (UTF-8 valide, sans caractère de
  contrôle), titre vide → « — » ; UID manquant → empreinte stable de (DTSTART, titre) ; doublon
  d'UID → plus grand `SEQUENCE` ; `STATUS:CANCELLED` : le rdv disparaît, une occurrence annulée
  devient une date exclue de sa série ; règle infra-journalière, trop longue ou invalide
  abandonnée (le rdv garde sa première occurrence) ; `RDATE` ignoré. Une **journée entière**
  (`VALUE=DATE`) est une date de calendrier, minuit UTC → minuit UTC, comme dans l'app ; les
  occurrences d'une série journée entière se repèrent par leur date, quel que soit le fuseau écrit
  dans `RECURRENCE-ID`.
- **Fuseaux** (`zones.go`) : TZID IANA, sinon la table Windows → IANA du CLDR (« Romance Standard
  Time » → `Europe/Paris`, Outlook et Exchange), sinon la fin d'un chemin (`/mozilla.org/…/Europe/
  Paris`), sinon `X-WR-TIMEZONE` du flux, sinon UTC. Un nom que la contrainte de la base refuse
  devient `UTC` (les instants restent justes). La lecture d'un texte est maison : `Prop.Text` de
  go-ical coupe à la première virgule non échappée.
- **Le décodeur de go-ical n'est pas écrit pour une donnée hostile** (`limits.go`) : il est
  récursif, construit chaque valeur de paramètre par concaténation octet par octet (temps
  quadratique) et **panique** sur certaines lignes mal formées (`SUMMARY;LANGUAGE=fr` sans
  deux-points). Une passe linéaire sur les lignes dépliées refuse avant lui une imbrication
  `BEGIN` > 8 et une partie « nom;paramètres » > 4 Kio (guillemets compris) ; `Parse` rattrape
  toute panique en `not_calendar`. Sans cela, un seul flux hostile arrêtait le worker entier,
  dépliage des séries compris. Au plus 20 000 VEVENT décodés ; une date hors 1900–3000
  (`RECURRENCE-ID`, `EXDATE` comprises) est écartée — Postgres refuse l'an 0.
- **Service** (`service.go`) : `SyncDue` prend les flux dus par lots de 10 et les relit un à un ;
  un échec noté n'arrête pas les autres ; un échec d'écriture en base n'est pas noté (le bail
  expire, le flux sera repris), sauf un **contenu que la base refuse** (SQLSTATE de classe 21,
  22 ou 23 → `ErrRejectedFeed`), noté `not_calendar` plutôt que relu en boucle toutes les
  10 minutes sans rien dire à l'utilisateur. `Run` se réveille toutes les minutes et à chaque notification
  `agora_ics` (nouveau flux, « Synchroniser maintenant », reconnexion de l'écoute).
- **Écoute partagée** (`worker/internal/database/listen.go`) : une seule connexion `LISTEN` pour
  `agora_recurrence` et `agora_ics` (chaque connexion Postgres coûte au serveur), reconnexion avec
  repli 1 s → 1 min, `OnConnected` de chaque abonnement à chaque (re)connexion.
- **Dépendances vendorisées** (`worker/vendor/`, `go mod vendor`) : le worker se compile hors
  ligne, à la version exacte relue en revue ; `go build` refuse un `go.mod` qui dériverait.

## Dans l'app (`features/calendar/`)

- **Importer** (« Mes agendas » → « Importer un agenda ») : lien, nom, couleur, et où trouver le
  lien chez Google, Outlook et Apple. Le champ vérifie la forme (`https://` ou `webcal://`, sans
  espace ni identifiants, ≤ 2 048) ; le serveur fait foi (`invalid_feed_url`, `too_many_feeds`).
  Le lien part à `add_ics_calendar` et **l'app ne le revoit jamais** (ni le brouillon, dont
  `toString` le tait).
- **État de synchro** dans la liste et l'éditeur d'agenda : « Première synchronisation en
  cours… », « Synchronisé le … », ou la raison du dernier échec (un code → un texte, en couleur
  d'erreur). Il arrive en temps réel ; tirer la liste la relit quand même.
- **« Synchroniser maintenant »** dans l'éditeur d'un agenda importé (`sync_calendar_now`).
- **Un rdv importé s'ouvre en lecture seule** (`ImportedEventSheet`) : titre, créneau, agenda,
  lieu, notes, et le seul réglage possible — ce que les groupes en voient (`set_event_visibility`,
  jamais touché par la synchro). Depuis une occurrence de série, le réglage vaut pour la série.
  Le dernier jour d'une journée entière se calcule par le calendrier, pas en retranchant 24 h :
  la nuit d'un changement d'heure n'en fait pas 24.
- **Providers liés au compte** : `calendarsProvider`, `agendaChangesProvider`,
  `calendarsChangesProvider` et `myGroupsProvider` attendent `currentUserIdProvider.future` :
  changer de compte dans la même session recharge tout, au lieu de servir ce qui avait été lu
  pour le compte précédent (ou pour une session périmée au chargement) ; le même compte réémis
  (rafraîchissement du jeton) ne recharge rien ; déconnecté, aucune requête anonyme. Un test
  qui lit ces providers les **écoute** d'abord : sans auditeur, Riverpod 3 les met en pause et
  la session n'arriverait jamais.

## Fichiers

| Fichier | Rôle |
|---|---|
| `supabase/migrations/20260922010000_ics_sync.sql` | contrat worker ↔ base, `sync_calendar_now`, temps réel sur `calendars` |
| `supabase/tests/ics_test.sql` | secret gardé, bail, application d'un flux (série, occurrence, orphelin, visibilité, inchangé, disparu), échecs, relance |
| `worker/ics/` | `feed.go` (types, codes), `guard.go`, `fetch.go`, `limits.go`, `parse.go`, `zones.go`, `service.go`, `pgstore.go` + tests unitaires (serveur TLS `httptest`, lignes qui font paniquer le décodeur) et `pgstore_integration_test.go` |
| `worker/internal/database/listen.go` | écoute LISTEN partagée, abonnements par canal |
| `app/lib/src/features/calendar/domain/user_calendar.dart` | `FeedSyncError`, `ImportedCalendarDraft`, `looksLikeFeedUrl` |
| `app/lib/src/features/calendar/presentation/` | `ImportCalendarScreen`, `ImportedEventSheet` (+ `eventWhenLabel`), `feed_sync_labels.dart`, `ColorPicker` |

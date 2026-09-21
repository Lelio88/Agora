# Agora

Vos agendas, ensemble. Chacun garde son agenda, le partage dans des groupes au niveau de détail
qu'il choisit, et un bot Discord tient le groupe au courant.

## À quoi ça sert

- **Un agenda à soi** : rdv saisis dans l'app ou importés depuis Google, Outlook ou iCloud par
  leur lien iCal.
- **Des groupes** : vue superposée des agendas des membres, rdv de groupe avec réponses,
  recherche des créneaux où tout le monde est libre, invitation par lien ou code.
- **La vie privée au rdv près** : pour chaque groupe, on montre le détail ou seulement
  « occupé » ; chaque agenda et chaque rdv peut être restreint, jusqu'à devenir invisible.
- **Un bot Discord** réglé depuis l'app : `/agenda`, `/dispo`, récap dans un salon, rappels.

Le projet en est à ses fondations. Les étapes suivantes sont dans
[`docs/roadmap.md`](docs/roadmap.md).

## Démarrage rapide

Prérequis : Flutter 3.47+, Go 1.26+, Docker, Supabase CLI 2.114+.

```bash
supabase start                 # backend local (API sur http://127.0.0.1:55321)
supabase test db               # tests du schéma et des règles de visibilité

cp app/config/local.json.example app/config/local.json
# y coller la clé « Publishable » affichée par `supabase status`

cd app && flutter run -d chrome --dart-define-from-file=config/local.json
cd worker && go run ./cmd/worker   # service de fond, santé sur http://localhost:8080/healthz
```

## Organisation

| Dossier | Contenu |
|---|---|
| `app/` | App Flutter (Android + web), français et anglais |
| `supabase/` | Schéma Postgres, règles d'accès, tests pgTAP |
| `worker/` | Service Go : import iCal, récurrences, bot Discord |
| `docs/` | [Architecture](docs/architecture.md) et [feuille de route](docs/roadmap.md) |

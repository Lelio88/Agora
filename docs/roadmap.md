# Feuille de route d'Agora

Périmètre de la v1, par étapes livrables l'une après l'autre. Chaque étape se termine sur des
tests verts et une doc à jour ([`architecture.md`](./architecture.md)).

| # | Étape | Contenu | État |
|---|---|---|---|
| 0 | Fondations | Dépôt, squelettes app + worker, schéma et règle de visibilité (tests pgTAP) | ✅ |
| 1 | Comptes | ✅ e-mail + code à 6 chiffres (inscription, mot de passe oublié), profil (nom, langue app + e-mails, fuseau), suppression du compte (groupes transmis) · à faire : Google, Discord, liaison Discord a posteriori | en cours |
| 2 | Agenda perso | Vue semaine/mois, créer/modifier des rdv, récurrence (RRULE), masquage par rdv et par agenda | à faire |
| 3 | Groupes | Créer, inviter (lien/code), rejoindre, quitter, transmettre ; réglage de partage par groupe ; vue superposée | à faire |
| 4 | Worker : récurrences | Connexion pgx, dépliage des RRULE sur fenêtre glissante, déclenché par LISTEN/NOTIFY | à faire |
| 5 | Import iCal | Ajout d'un lien, relecture périodique (ETag), garde SSRF, état de synchro visible | à faire |
| 6 | Rdv de groupe | Agenda du groupe, réponses présent / absent / peut-être | à faire |
| 7 | Créneaux communs | Recherche des créneaux libres dans l'app (`invisible` = libre, `busy` = pris) | à faire |
| 8 | Bot Discord | Interactions signées, `/agenda`, `/dispo`, liaison d'un salon, récaps, rappels, réglages dans l'app | à faire |
| 9 | Mise en ligne | Supabase auto-hébergé + worker sur Hetzner (réglages `GOTRUE_*` et gabarits servis par URL), CAPTCHA sur les formulaires de compte, pages légales (dont : les rdv de groupe proposés survivent à la suppression du compte), fiche Play Store (lien web de suppression du compte : la version web) | à faire |

## Décisions de cadrage (2026-09-21)

- Public visé : **tout public**, Play Store. Android + web (Flutter) ; iOS plus tard.
- Synchro v1 : **lien iCal en lecture seule**. L'OAuth Google/Outlook et la synchro dans les deux
  sens sont hors v1.
- Vie privée : réglage **par groupe** + **par agenda** + **par rdv**, le plus restrictif
  l'emporte ; deux niveaux de masquage (`busy`, `invisible`).
- Discord : réponses visibles du seul demandeur ; récaps publics plafonnés à « occupé » pour les
  rdv perso.
- Langues : FR + EN dès le départ. `applicationId` : `app.agora`.

# Feuille de route d'Agora

Périmètre de la v1, par étapes livrables l'une après l'autre. Chaque étape se termine sur des
tests verts et une doc à jour ([`architecture.md`](./architecture.md)).

| # | Étape | Contenu | État |
|---|---|---|---|
| 0 | Fondations | Dépôt, squelettes app + worker, schéma et règle de visibilité (tests pgTAP) | ✅ |
| 1 | Comptes | ✅ e-mail + code à 6 chiffres (inscription, mot de passe oublié), profil (nom, langue app + e-mails, fuseau), suppression du compte (groupes transmis) · à faire : Google, Discord, liaison Discord a posteriori | en cours |
| 2 | Agenda perso | ✅ vues jour/semaine/mois/planning (kalender), créer/modifier/supprimer, séries avec « cette occurrence / toute la série », masquage par rdv et par agenda, plusieurs agendas (couleur, affichage), glisser-déposer | ✅ |
| 3 | Groupes | ✅ créer, inviter (code + lien web), rejoindre avec le partage choisi, rôles (admins), transmettre, quitter, exclure ; vue superposée (couleur par membre) · lien ouvrant l'app Android : avec le domaine (étape 9) | ✅ |
| 4 | Worker : récurrences | ✅ pgx en rôle restreint, dépliage sur fenêtre glissante (1 an avant, 2 ans après), LISTEN/NOTIFY avec reconnexion, dépliage complet toutes les 6 h | ✅ |
| 5 | Import iCal | ✅ ajout d'un lien (aide Google/Outlook/Apple), relecture toutes les 30 min par le worker (ETag, bail, délai croissant), garde SSRF sur l'adresse résolue, état de synchro en temps réel, « Synchroniser maintenant », rdv importés en lecture seule (visibilité réglable) | ✅ |
| 6 | Rdv de groupe | ✅ proposer un rdv au groupe (tout membre ; créateur et admins modifient), fiche avec réponses présent / peut-être / absent (par occurrence pour une série), rdv de groupe dans l'agenda perso (ma réponse sur la tuile), agendas de groupe à montrer ou masquer | ✅ |
| 7 | Créneaux communs | ✅ « Trouver un créneau » : durée, période, heures, week-ends, membres requis ; `invisible` = libre (signalé), `busy` = pris, rdv du groupe = pris ; un rdv accepté (« présent ») dans un autre groupe rend occupé ; un appui propose le rdv | ✅ |
| 8 | Bot Discord | Interactions signées, `/agenda`, `/dispo`, liaison d'un salon, récaps, rappels, réglages dans l'app | à faire |
| 9 | Mise en ligne | Supabase auto-hébergé + worker sur Hetzner (réglages `GOTRUE_*` et gabarits servis par URL), CAPTCHA sur les formulaires de compte, pages légales (dont : les rdv de groupe proposés survivent à la suppression du compte), fiche Play Store (lien web de suppression du compte : la version web) ✅ en ligne sur le Hetzner partagé : `agora.heianenterprise.com` (app web) et `api.agora.heianenterprise.com`, déploiement par `git push origin main:release`, répétition locale avant chaque changement ([`deployment.md`](./deployment.md)) · pages légales publiées (`/legal/`, bilingues : confidentialité, mentions, conditions) · reste avant d'ouvrir au public : CAPTCHA dans l'app, fiche Play Store | en cours |

## Décisions de cadrage (2026-09-21)

- Public visé : **tout public**, Play Store. Android + web (Flutter) ; iOS plus tard.
- Synchro v1 : **lien iCal en lecture seule**. L'OAuth Google/Outlook et la synchro dans les deux
  sens sont hors v1.
- Vie privée : réglage **par groupe** + **par agenda** + **par rdv**, le plus restrictif
  l'emporte ; deux niveaux de masquage (`busy`, `invisible`).
- Discord : réponses visibles du seul demandeur ; récaps publics plafonnés à « occupé » pour les
  rdv perso.
- Langues : FR + EN dès le départ. `applicationId` : `app.agora`.

# Déclarations de la console Play

Les réponses aux questionnaires obligatoires, avec ce qui les justifie. **Play
les réexamine à chaque mise à jour** : sans ce fichier, elles se redonnent de
mémoire, et une réponse qui change sans raison est un motif de rejet.

Chaque ligne est une constatation vérifiable dans le dépôt, pas un souvenir.
Quand le code change, c'est ici qu'il faut revenir : la table à la fin dit quoi
relire.

---

## Accès à l'application

| Champ | Réponse |
|---|---|
| Une partie de l'app est-elle limitée ? | **Oui** — aucun écran n'est accessible sans compte |
| Nom du jeu d'identifiants | `Reviewer account with sample data` |
| Identifiant | `play-review@agora.heianenterprise.com` |
| Mot de passe | dans `../../../.agora-secrets/play-review.env` |
| Accès complet à tout le contenu ? | **Oui** — ni achat intégré, ni abonnement, ni contenu réservé |

Le compte et sa scène sont recréés par `tools/store/seed_review.py`, et le mot
de passe tourné par `tools/store/rotate_review_password.py`. Le compte est en
**anglais** (`profiles.locale = 'en'`) : l'app suit la langue du profil avant
celle de l'appareil, et les instructions ci-dessous citent les libellés
anglais.

Instructions d'accès — **500 caractères maximum**, et celles-ci en font 495 :

```
Already confirmed and filled with sample data: sign in directly, do not register.
Tick the Cloudflare anti-bot box before signing in.
Agenda tab: week view, personal + imported iCal calendar.
Groups tab: open "Coloc" for the 3 members' shared week; those who share only availability show as "Busy", no title.
In "Coloc": calendar icon = "Common free times"; Saturday event "Raclette" = each member's answer.
Profile icon (top right): account deletion, privacy policy.
This account is in English.
```

**Si un relecteur supprime le compte**, les identifiants meurent avec lui :
relancer `seed_review.py` puis `rotate_review_password.py`, et remettre le mot
de passe dans la console.

---

## Annonces

**Non, l'application ne contient pas d'annonces.**

Vérifié sur `app/pubspec.lock`, dépendances transitives comprises : aucune
occurrence d'AdMob, google_mobile_ads, AppLovin, Unity Ads, ironSource,
Facebook Audience, Adjust ni AppsFlyer.

---

## Création de compte

**Nom d'utilisateur et mot de passe** — et rien d'autre.

Google et Discord sont câblés côté serveur (`GOTRUE_EXTERNAL_*` dans
`deploy/docker-compose.prod.yml`) mais **désactivés** : les clés ne sont pas
dans le `.env` de production, donc les variables retombent sur `false`, et
aucun écran de compte n'a de bouton pour eux. Les déclarer se vérifierait d'un
coup d'œil sur l'écran de connexion.

Le jour où ils sont activés : cocher **OAuth** en plus, et prévenir que le
compte de revue ne les utilise pas.

---

## Âge cible et contenu

| Question | Réponse |
|---|---|
| Tranches d'âge visées | **18 ans et plus**, uniquement |
| Application conçue pour les enfants ? | **Non** |
| Les visuels pourraient-ils attirer involontairement les enfants ? | **Non** |
| La fiche cible-t-elle les enfants ? | **Non** |

**Aucune tranche sous 13 ans, jamais.** Cocher 12 ans ou moins ferait entrer
Agora dans le programme Familles : conformité COPPA, interdiction de collecter
des données personnelles d'enfants sans consentement parental vérifiable,
revue renforcée. Une application qui demande une adresse e-mail et stocke des
agendas n'y survit pas.

18+ ne restreint pas l'installation — le champ déclare le public visé, pas un
âge minimum. Il évite en revanche les règles Play sur les données de mineurs,
qui s'appliqueraient dès la tranche 16-17.

Ce qui rend les trois « non » défendables : utilitaire d'organisation, sans
personnage, sans univers ludique, sans gamification. Icône en grille d'agenda
sur fond nuit, captures montrant des semaines de travail et des créneaux,
description parlant de colocation, d'équipe et de club. L'intro emploie des
couleurs vives, mais ce sont des blocs d'agenda abstraits.

---

## Classification du contenu (IARC)

| Champ | Réponse |
|---|---|
| Catégorie | Application → **Utilitaire, productivité, communication ou autre** |
| E-mail de contact | `heianenterpriseyt@gmail.com` (la même que sur les pages légales) |

Pas « Réseaux sociaux » : ni fil, ni profil public, ni découverte. On rejoint
un groupe **uniquement par code** (`join_group(p_code)`), et aucune recherche
d'utilisateurs ou de groupes n'existe dans l'app.

| Question | Réponse |
|---|---|
| Violence, contenu sexuel, langage grossier, drogues, jeux d'argent, horreur | **Non** |
| Achats de biens numériques | **Non** |
| Accès non filtré à Internet (navigateur intégré) | **Non** |
| Partage de la position physique avec d'autres utilisateurs | **Non** |
| Les utilisateurs peuvent-ils interagir ou échanger du contenu ? | **Oui** |
| Ce contenu est-il accessible publiquement ? | **Non** |

**Le « oui » est obligatoire et se vérifie.** Les membres d'un groupe voient le
texte que les autres saisissent : titres de rendez-vous (200 caractères),
descriptions (5 000), lieux (300), noms et descriptions de groupes. C'est du
contenu généré par les utilisateurs, même sans messagerie.

**Le « non » au partage de position** tient parce que le champ « lieu » est du
texte libre au clavier, pas une position d'appareil : l'app ne demande aucune
permission de localisation.

Classification obtenue attendue : **PEGI 3 / ESRB Everyone**, avec la mention
« interaction entre utilisateurs », qui n'empêche rien.

**Ce que Google peut soulever** : répondre « oui » à l'interaction amène
parfois des questions sur la modération. Agora n'a ni signalement, ni blocage.
C'est défendable — le contenu n'est visible que par les membres d'un groupe
privé rejoint sur code, jamais par des inconnus — mais si Google insiste, il
faudra un moyen de signaler un abus (quitter un groupe existe déjà).

---

## Sécurité des données

### Les trois questions d'ouverture

| Question | Réponse | Pourquoi |
|---|---|---|
| Collecte ou partage de données ? | **Oui** | comptes et agendas |
| Chiffrées en transit ? | **Oui** | tout passe en HTTPS/TLS |
| Suppression possible ? | **Oui** | Profil → Supprimer mon compte, et par e-mail |

### Les types déclarés

Pour **tous** : partagées = **Non**, éphémères = **Non**.

| Catégorie → Type | Requise | Finalités |
|---|---|---|
| Informations personnelles → **Adresse e-mail** | Obligatoire | Fonctionnalité, Gestion du compte |
| Informations personnelles → **Nom** | Obligatoire | Fonctionnalité, Gestion du compte |
| Informations personnelles → **ID utilisateur** | Obligatoire | Fonctionnalité, Gestion du compte |
| Agenda → **Événements d'agenda** | Facultative | Fonctionnalité |
| Activité dans l'app → **Autres actions** | Facultative | Fonctionnalité |

« Autres actions » couvre l'appartenance aux groupes, le rôle, le niveau de
partage, les invitations créées et les réponses aux rendez-vous.

**Éphémère : non, pour les cinq.** Une donnée éphémère est lue en mémoire le
temps d'une requête puis jetée ; chacun de ces types atterrit dans une table
Postgres et y reste jusqu'à la suppression du compte. La seule donnée
réellement éphémère du produit est l'adresse IP vue par Cloudflare pendant le
contrôle anti-robot — et elle n'est pas déclarée, précisément pour cette
raison.

**Requis ou facultatif** : l'inscription valide `displayName`, `email` et
`password` (`sign_up_screen.dart`), les trois sont donc obligatoires. Un
compte peut en revanche rester sans aucun rendez-vous ni groupe.

**Partagées : non.** Google définit le partage comme un transfert vers un
tiers et **exclut les transferts déclenchés par l'utilisateur**. Voir l'agenda
d'un colocataire suppose d'avoir rejoint son groupe et choisi son niveau de
partage. Hetzner et Brevo sont des sous-traitants, pas des destinataires.

### Les types que l'on ne déclare pas

| Catégorie | Pourquoi c'est sûr |
|---|---|
| Emplacement | le manifeste fusionné du build de publication ne demande que `INTERNET` |
| Photos et vidéos | `profiles.avatar_url` existe en base, mais aucun écran ne permet d'envoyer une image — ni `image_picker`, ni `file_picker` ; les `CircleAvatar` du code sont des pastilles de couleur |
| ID d'appareil | aucun identifiant publicitaire, aucun `device_info`, aucun Firebase, aucune notification push |
| Infos sur l'app et performances | le journal passe par `dart:developer` et ne quitte pas l'appareil ; aucun rapport de plantage |
| Contacts, Fichiers, Messages, Navigation Web, Santé, Finances | rien de tel dans les dix tables du schéma |

Les seuls hôtes contactés par l'app sont le serveur Supabase d'Agora et
`challenges.cloudflare.com` pour le CAPTCHA.

### Le point non tranché

**Le mot de passe.** Play ne propose aucun type pour les identifiants
d'authentification. Il n'est pas déclaré, faute de catégorie ; la page de
confidentialité le mentionne déjà (« jamais en clair : il est haché »). À
reprendre si Google ajoute un type adapté.

---

## Règles et confidentialité

| Champ | Valeur |
|---|---|
| Politique de confidentialité | `https://agora.heianenterprise.com/legal/confidentialite.html` |
| Suppression du compte | même URL, section « Supprimer votre compte » |

**Limite connue** : Google préfère une page dédiée à la suppression, et cette
section n'a même pas d'ancre — le relecteur arrive en haut d'une page longue.
Une page `/legal/suppression.html` reste à faire.

---

## Quand faut-il rouvrir ce fichier

| Changement dans le code | Déclaration à revoir |
|---|---|
| Nouvelle dépendance dans `pubspec.yaml` | Annonces, ID d'appareil, Infos sur l'app |
| Nouvelle permission dans un `AndroidManifest.xml` | Emplacement, et le type correspondant |
| Nouvelle table ou colonne portant une donnée d'utilisateur | Types déclarés |
| Envoi d'image de profil enfin implémenté | Photos et vidéos |
| Clés OAuth posées en production | Création de compte → ajouter OAuth |
| Achat intégré ajouté | Accès complet au contenu → fournir un compte payant |
| Mascotte, gamification ou univers ludique ajouté | Âge cible → les trois « non » ne tiennent plus |
| Messagerie, commentaires ou groupes publics ajoutés | Classification → interaction, contenu public, modération |
| Crash reporting ou analytics ajouté | Infos sur l'app et performances |

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

### Le premier écran : trois champs

| Champ | Réponse |
|---|---|
| Adresse e-mail (saisie) | `heianenterpriseyt@gmail.com` — la même que sur les pages légales |
| Catégorie (trois boutons radio) | **Tous les autres types d'applications** |
| Conditions de l'IARC (case à cocher) | **Cocher** — obligatoire, sans alternative |

**Le piège est le bouton du milieu.** « Social ou Communication » se définit
par son *objectif principal* : rencontrer des personnes ou communiquer avec
elles (Facebook, Skype, SMS). Agora n'a aucune messagerie — pas de chat, pas
de commentaire, pas de fil, pas de profil public — et on ne rejoint un groupe
que par code (`join_group(p_code)`). Son objet est d'organiser des agendas ;
le partage est le moyen, pas la finalité.

Ce choix ne dissimule rien : le questionnaire qui suit pose quand même la
question de l'interaction entre utilisateurs, et la réponse y est **oui**.

L'adresse est transmise aux organismes de classification (PEGI, ESRB, USK) :
c'est l'objet même des conditions à cocher.

### Le questionnaire qui suit

Neuf questions, toutes en oui/non. **Une seule réponse est positive.**

| Question (libellé de la console) | Réponse |
|---|---|
| Contenu classifiable livré dans le paquet (code, ressources) | **Non** |
| Partage de contenu utilisateur (voix, texte, images, audio) | **Oui** |
| Contenu en ligne hors téléchargement initial (type Netflix, Amazon, IA) | **Non** |
| Promotion ou vente de produits soumis à l'âge | **Non** |
| Partage de l'emplacement physique précis avec d'autres utilisateurs | **Non** |
| Achat d'articles numériques | **Non** |
| Récompenses en espèces, cartes cadeaux, play-to-earn, crypto, NFT | **Non** |
| Navigateur Web ou moteur de recherche | **Non** |
| Produit essentiellement d'actualité ou d'éducation | **Non** |

**« Non » au contenu livré dans le paquet** : l'application n'embarque qu'un
seul asset, `app/assets/audio/agora_intro.mp3` — le jingle de six notes. Ni
image hors icônes de lanceur, ni vidéo, ni police tierce. Le reste est du code
et des chaînes d'interface.

**« Oui » au partage de contenu utilisateur**, et c'est la réponse qui coûte
quelque chose. Agora n'a ni voix, ni image, ni audio, ni messagerie, ni
commentaire — mais du texte libre circule entre membres : `events.title`
(200 caractères), `events.description` (**5 000**), `events.location` (300),
`groups.name` (60) et sa description (500). Un membre écrit, les autres
lisent. Répondre non se démentirait en ouvrant le rendez-vous « Raclette » du
compte de revue, et une classification obtenue sur une réponse fausse
s'annule. Coût assumé : le descripteur « interaction entre utilisateurs ».

**« Non » au contenu en ligne** : l'app ne propose aucun catalogue, aucun flux
éditorial, aucun contenu généré par IA. Les agendas importés par iCal viennent
bien de l'extérieur, mais ce sont les données de l'utilisateur lui-même, qu'il
a désignées par un lien — pas du contenu distribué par l'application.

**« Non » au navigateur** : `webview_flutter` sert uniquement à afficher la
page du CAPTCHA, à une URL construite par `captchaConfigProvider` sur le
domaine d'Agora. Aucune navigation libre, aucune barre d'adresse.

**« Non » aux achats et à la crypto** : aucune permission `com.android.vending
.BILLING` dans le manifeste fusionné, aucune dépendance `in_app_purchase`. Les
deux occurrences de « crypto » dans `pubspec.lock` sont le paquet Dart de
hachage, dépendance de Supabase.

**« Non » à l'emplacement** : aucune permission de localisation ; le champ
« lieu » est du texte saisi au clavier.

Classification attendue : **PEGI 3 / ESRB Everyone**, assortie du descripteur
d'interaction. L'effet exact sur l'âge dépend de chaque organisme.

### Les sept sous-questions ouvertes par ce « oui »

Répondre « oui » au partage de contenu utilisateur déclenche un second bloc.

| Sous-question | Réponse |
|---|---|
| Le contenu utilisateur partagé est-il la **source principale** du contenu ? | **Non** |
| Partage **public** de nudité | **Non** |
| Partage **public** de violence explicite réelle | **Non** |
| Possibilité de **bloquer** des utilisateurs ou du contenu | **Non** |
| Possibilité de **signaler** | **Non** |
| **Modération** des conversations | **Non** |
| Interactions limitables **aux invités uniquement** | **Oui** |

**La première est un piège, et la réponse est non.** Répondre oui classerait
Agora comme plateforme de contenu généré par les utilisateurs, ce qui
déclenche la politique UGC de Google : signalement, modération et blocage
deviennent exigibles. L'app n'en a aucun, et le refus serait quasi certain.
C'est aussi faux : la source principale du contenu, pour chaque utilisateur,
est **son propre agenda** — ce qu'il saisit et ce qu'il importe par iCal. Le
contenu d'autrui n'apparaît que s'il rejoint un groupe, et un compte sans
aucun groupe est pleinement fonctionnel.

**Nudité et violence publiques : non, doublement.** Rien n'est public dans
Agora, et aucune image ne peut être envoyée — il n'existe ni `image_picker`,
ni `file_picker`, ni stockage de fichiers.

**Le trio blocage / signalement / modération est à « non », et c'est exact** :
aucune de ces fonctions n'existe. Sur une application sociale, ce trio pèserait
lourd ; ici la dernière question l'annule.

**« Oui » aux interactions limitées aux invités, et c'est ce qui tient
l'ensemble.** On ne rejoint un groupe que par un code transmis de la main à la
main (`join_group(p_code)`) : ni annuaire, ni recherche, ni profil public.
Aucun inconnu ne peut atteindre un utilisateur.

Nuance à connaître si Google revient sur le blocage : `leaveGroup` permet de
quitter un groupe et `removeMember` d'en retirer quelqu'un. Ce n'est pas un
blocage au sens de la question — il n'y a pas de liste de personnes bloquées —
mais c'est l'argument à avancer, avec pour parade l'ajout d'un signalement.

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

## Catégorie et tags

| Champ | Réponse |
|---|---|
| Type | **Applications** (pas Jeux) |
| Catégorie | **Productivité** |
| Tags | cinq au maximum, liste fermée — voir ci-dessous |

**Productivité**, parce que c'est là que vivent les agendas : Google Agenda,
Outlook, Todoist. Les deux tentations à écarter : **Outils** est un fourre-tout
de lampes de poche et de convertisseurs, où une app d'agenda est invisible ;
**Social** décrirait un réseau, et contredirait la catégorie refusée à l'IARC.

Tags, par ordre de pertinence — les libellés exacts dépendent de la liste que
propose la console :

1. Agenda / Calendrier — le cœur du produit
2. Planification ou Gestion du temps
3. Collaboration ou Travail d'équipe — ce qui distingue Agora d'un agenda seul
4. Organisation personnelle
5. Groupes ou Partage, s'il existe

N'en prendre cinq que s'ils collent : Google dégrade la visibilité des fiches
dont les tags ne correspondent pas au produit.

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

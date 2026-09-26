# Fiche Play Store

Ce dossier contient ce qui part sur la fiche : les captures, l'icône, le
bandeau, et les textes. Tout y est **reproductible** — rien n'a été composé à
la main dans un éditeur d'images, et rien ne doit l'être : une capture se
refait à chaque libellé qui change, et une icône à chaque fois qu'on la
regarde sur un vrai téléphone.

## Ce qu'il y a ici

| Fichier | Produit par |
|---|---|
| [`declarations-play.md`](declarations-play.md) | les réponses aux questionnaires obligatoires, et ce qui les justifie |
| `01-agenda.png` … `06-import.png` | captures d'émulateur, scène posée par [`tools/store/seed_demo.py`](../../tools/store/seed_demo.py) |
| `icon-512.png`, `feature-1024x500.png` | [`tools/store/make_store_assets.py`](../../tools/store/make_store_assets.py) |

Le même script écrit aussi les `mipmap-*` d'Android, l'icône adaptative et le
fond de l'écran de démarrage : l'icône de la fiche et celle du lanceur ne
peuvent donc pas diverger.

## Refaire les captures

Elles viennent d'un **émulateur**, pas du navigateur : Flutter web ignore le
ratio de pixels émulé et rend un layout de tablette, inutilisable pour une
fiche.

```bash
supabase db reset && python tools/store/seed_demo.py   # la scène de démo

# Un émulateur au format attendu par Play (9:16) et une barre de statut propre
adb shell wm size 1080x1920 && adb shell wm density 420
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0930
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false

# Le clavier virtuel décale le layout et fausse les appuis scriptés
adb shell settings put secure show_ime_with_hard_keyboard 0

cd app && flutter build apk --profile --target-platform android-x64 \
  --dart-define-from-file=config/emulateur.json     # SUPABASE_URL=http://10.0.2.2:55321
adb install -r -t build/app/outputs/flutter-apk/app-profile.apk
adb shell cmd locale set-app-locales app.agora --locales fr-FR
adb exec-out screencap -p > app/store/01-agenda.png
```

Trois pièges qui coûtent une heure chacun :

- **Le build `profile`, pas `debug`** : le bandeau « DEBUG » barre le coin de
  toute capture prise en debug.
- **Le trafic en clair** n'est rouvert que dans les variantes `debug` et
  `profile` du manifeste ; sans quoi un build de développement ne peut pas
  joindre la pile Supabase locale.
- **La langue** vient de `cmd locale set-app-locales`, pas des réglages de
  l'émulateur : c'est la préférence par application d'Android 13.

## Construire le binaire à envoyer

```bash
# config/prod.json est gitignoré : le recomposer depuis le coffre si besoin
# (SUPABASE_URL et AGORA_WEB_URL = API_URL et SITE_URL de ../.agora-secrets/
# supabase.env ; SUPABASE_PUBLISHABLE_KEY = ANON_KEY ; la clé de site
# Turnstile est dans turnstile.env).
cd app && flutter build appbundle --release --dart-define-from-file=config/prod.json

# Vérifier la signature AVANT d'envoyer, jamais après : un binaire signé avec
# la clé de débogage est accepté par Gradle sans un mot et refusé par Play une
# demi-heure plus tard, sans indice sur la cause.
"/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe"   -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
# Doit afficher : CN=Lelio Buton, OU=Agora, O=Heian Enterprise
# Ne doit jamais afficher : CN=Android Debug
```

Le fichier reste dans `app/build/app/outputs/bundle/release/` — les artefacts
de compilation ne remontent pas à la racine du conteneur.

## Les textes de la fiche

### Titre — validé

```
Agora — agendas partagés
```

24 caractères sur 30. « Agora » seul ne dit rien dans une recherche ; les deux
mots qui suivent portent la requête.

### Description courte — validée

```
Chacun partage ce qu'il veut, le groupe voit qui est pris et trouve un créneau.
```

78 caractères sur 80. Elle énonce la contrepartie (vous gardez la main) avant
le bénéfice (on trouve une date) — c'est l'ordre dans lequel l'app est
construite.

### Description longue — validée

1 743 caractères sur 4 000. **Chaque paragraphe tient sur une seule ligne** :
la console affiche le texte tel quel, et des retours à la ligne au milieu
d'une phrase donneraient un rendu haché sur téléphone. Les intertitres sont en
capitales et non en gras — ce champ n'accepte qu'un HTML très limité, des
astérisques s'y afficheraient tels quels.

```
Agora, c'est votre agenda — et celui de vos groupes.

Chacun a le sien : les rendez-vous que vous y notez, et ceux qui arrivent de Google Agenda, Outlook ou Apple par un simple lien iCal. Vous rejoignez ensuite un groupe — la coloc, la famille, l'équipe, le club — et c'est là que vous choisissez ce que vous montrez.

UN NIVEAU DE DÉTAIL PAR GROUPE

Pour chaque groupe, vous décidez : tous les détails, ou seulement « occupé » sans dire de quoi il s'agit. Le même jeudi soir peut être « Cours de dessin » pour vos colocataires et « occupé » pour le club de rando. Un rendez-vous précis, ou un agenda entier, peut aussi rester invisible.

VOIR QUI EST PRIS, SANS DEMANDER À PERSONNE

L'agenda du groupe superpose les semaines de ses membres, une couleur chacun. On y lit les creux, pas les secrets.

TROUVER LE CRÉNEAU QUI VA À TOUT LE MONDE

Dites la durée qu'il vous faut et la période à regarder : Agora liste les moments où personne n'est pris. Il n'y a plus qu'à en choisir un, et le rendez-vous est proposé au groupe.

PROPOSER, ET SAVOIR QUI VIENT

Un rendez-vous de groupe se répond en un appui : présent, peut-être, absent. Chacun voit où en sont les autres.

VOS AGENDAS EXTÉRIEURS, À JOUR TOUT SEULS

Collez le lien iCal de votre agenda Google, Outlook ou Apple, de votre emploi du temps ou de votre planning de travail : Agora le relit régulièrement. Ce lien n'est jamais affiché ni transmis à qui que ce soit.

CE QU'AGORA NE FAIT PAS

Pas de publicité, pas de revente de données, pas de profilage. Vos rendez-vous ne servent qu'à ce que vous en faites. Vous supprimez votre compte quand vous voulez, depuis l'application, et vos agendas partent avec.

Agora fonctionne aussi dans un navigateur : https://agora.heianenterprise.com
```

Trois absences volontaires : **le bot Discord** (il n'existe pas ; Google
sanctionne les descriptions qui promettent des fonctions absentes), **les
liens légaux** (Play a des champs dédiés) et **tout superlatif**. Seule
l'adresse web de l'app figure, parce qu'aucun champ ne la met en avant.

### Notes de version

À rédiger au premier envoi.

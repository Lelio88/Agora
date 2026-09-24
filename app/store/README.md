# Fiche Play Store

Ce dossier contient ce qui part sur la fiche : les captures, l'icône, le
bandeau, et les textes. Tout y est **reproductible** — rien n'a été composé à
la main dans un éditeur d'images, et rien ne doit l'être : une capture se
refait à chaque libellé qui change, et une icône à chaque fois qu'on la
regarde sur un vrai téléphone.

## Ce qu'il y a ici

| Fichier | Produit par |
|---|---|
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

### Description longue, notes de version, questionnaires

À valider ; ils viendront ici au fur et à mesure, pour que la fiche se
reconstitue depuis le dépôt et non depuis la mémoire de la console.

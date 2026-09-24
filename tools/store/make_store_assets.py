"""Dessine l'identité visuelle d'Agora : icône, icône adaptative Android,
écran de démarrage et bandeau du Play Store.

**Un script plutôt que des PNG déposés**, pour la même raison que
`tools/sounds/gen_intro_jingle.py` : une icône se reprend — une teinte qui
passe mal sur fond sombre, une marge de sécurité qu'Android rogne davantage
qu'on croyait. Le script les régénère toutes d'un coup et garde les cinq
tailles cohérentes entre elles ; cinq PNG figés divergent au premier retour.

**Le dessin est celui de l'intro, réduit.** Trois colonnes — un membre
chacune, aux couleurs de `app/lib/src/common_widgets/palette.dart` — et la
bande indigo du créneau commun qui les traverse. C'est le même geste que
`tools/mockups/agora_intro.html` arrêté sur sa cinquième battue : qui voit
l'icône a déjà vu l'app.

**Les proportions ne sont pas libres.** Android rogne l'icône adaptative en
cercle, en carré arrondi ou en goutte selon le lanceur : seuls les 66 % du
centre sont garantis visibles (voir [SUR_ADAPTATIVE]). Le dessin est donc
calculé dans un carré de référence, puis posé à l'échelle voulue — jamais
redimensionné depuis un PNG, qui rendrait les bords mous.

Usage :

    python tools/store/make_store_assets.py

Écrit l'icône du Play Store et le bandeau dans `app/store/`, les mipmaps et
l'icône adaptative dans `app/android/app/src/main/res/`. Dépend de `Pillow`.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RACINE = Path(__file__).resolve().parents[2]
STORE = RACINE / "app" / "store"
RES = RACINE / "app" / "android" / "app" / "src" / "main" / "res"

#: Relevées sur l'app : `_seedColor` d'app.dart, puis `appPalette`.
INDIGO = (63, 81, 181)
MEMBRES = [(30, 136, 229), (67, 160, 71), (229, 57, 53)]
BLANC = (255, 255, 255)

#: **L'icône est sombre alors que l'app est claire, et c'est délibéré.** Trois
#: essais ont été comparés à 48 px : sur fond clair, les fûts disparaissent et
#: il ne reste que des taches de couleur ; sur fond indigo avec une bande
#: blanche, la bande se confond avec les fûts et le dessin se lit « H ». Seul
#: le fond nuit laisse les trois lectures intactes — colonnes, créneaux pris,
#: bande commune. L'écran de démarrage reprend ce fond, pour que le lancement
#: prolonge l'icône au lieu de la contredire.
NUIT_HAUT = (26, 27, 58)
NUIT_BAS = (38, 40, 80)

#: La bande du créneau commun. Sur fond nuit, elle doit se détacher des fûts
#: blancs : ce périwinkle est l'indigo de la marque éclairci jusqu'à tenir
#: contre du blanc.
BANDE = (124, 140, 255)

#: Le fût d'un agenda, posé sur le fond nuit.
FUT = BLANC

#: Les mêmes créneaux que l'intro, en fraction de la hauteur de colonne, et la
#: même bande libre. Les changer ici sans les changer là-bas ferait diverger
#: l'icône de l'animation qu'elle résume.
BLOCS = [
    [(0.06, 0.26), (0.70, 0.86)],
    [(0.13, 0.35), (0.76, 0.96)],
    [(0.41, 0.56), (0.82, 0.98)],
]
LIBRE = (0.58, 0.70)

#: Part du côté occupée par le dessin sur l'icône adaptative. Android ne
#: garantit que les 66 % centraux ; en deçà de cette marge, un lanceur rond
#: couperait les colonnes extérieures.
SUR_ADAPTATIVE = 0.56

#: Part du côté sur une icône classique, qui n'est pas rognée.
SUR_PLEINE = 0.72

#: Tailles Android, par densité.
MIPMAPS = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def dessiner_marque(img: Image.Image, cote: float, cx: float, cy: float) -> None:
    """Pose la marque — trois colonnes et la bande — centrée sur (cx, cy).

    [cote] est le côté du carré qui la contient ; tout le reste en découle,
    de sorte que le dessin soit identique à toutes les tailles.
    """
    d = ImageDraw.Draw(img)

    col_l = cote * 0.26
    ecart = cote * 0.37
    col_h = cote
    haut = cy - col_h / 2

    for i, (couleur, blocs) in enumerate(zip(MEMBRES, BLOCS)):
        x = cx + (i - 1) * ecart - col_l / 2
        rayon = col_l * 0.22
        d.rounded_rectangle(
            [x, haut, x + col_l, haut + col_h], radius=rayon, fill=FUT
        )
        marge = col_l * 0.16
        for a, b in blocs:
            d.rounded_rectangle(
                [x + marge, haut + a * col_h, x + col_l - marge, haut + b * col_h],
                radius=col_l * 0.14,
                fill=couleur,
            )

    # La bande du créneau commun traverse les trois colonnes : dans l'app comme
    # ici, elle n'appartient à personne.
    large = ecart * 2 + col_l
    d.rounded_rectangle(
        [
            cx - large / 2,
            haut + LIBRE[0] * col_h,
            cx + large / 2,
            haut + LIBRE[1] * col_h,
        ],
        radius=col_l * 0.18,
        fill=BANDE,
    )


def fond_nuit(img: Image.Image) -> None:
    """Le dégradé de fond, du haut vers le bas. Un aplat suffirait à petite
    taille, mais pas en 512 : il y paraîtrait imprimé."""
    d = ImageDraw.Draw(img)
    hauteur = img.size[1]
    for y in range(hauteur):
        k = y / max(1, hauteur - 1)
        d.line(
            [(0, y), (img.size[0], y)],
            fill=tuple(int(a + (b - a) * k) for a, b in zip(NUIT_HAUT, NUIT_BAS)),
        )


def carre(taille: int, part: float, transparent: bool = False) -> Image.Image:
    """Une image carrée portant la marque, dessinée en quadruple puis réduite.

    Le suréchantillonnage remplace l'anticrénelage, que Pillow n'applique pas
    aux primitives : dessiner directement à 48 px donnerait des bords en
    escalier sur les petites densités.

    [transparent] laisse le fond vide : c'est l'avant-plan d'une icône
    adaptative, dont Android compose lui-même l'arrière-plan.
    """
    facteur = 4
    grand = Image.new("RGBA", (taille * facteur, taille * facteur), (0, 0, 0, 0))
    if not transparent:
        fond_nuit(grand)
    cote = taille * facteur
    dessiner_marque(grand, cote * part, cote / 2, cote / 2)
    return grand.resize((taille, taille), Image.LANCZOS)


def masque_arrondi(img: Image.Image, rayon_part: float = 0.22) -> Image.Image:
    """Arrondit les coins — pour l'icône classique, qu'aucun lanceur ne rogne."""
    masque = Image.new("L", img.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=int(img.size[0] * rayon_part),
        fill=255,
    )
    sortie = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sortie.paste(img, mask=masque)
    return sortie


def police(taille: int) -> ImageFont.FreeTypeFont:
    """Une grotesque disponible sur le poste, à défaut la police par défaut."""
    for nom in ("segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(nom, taille)
        except OSError:
            continue
    return ImageFont.load_default(taille)


def bandeau() -> Image.Image:
    """Le bandeau 1024 x 500 du Play Store : la marque, le nom, la promesse.

    Play recadre ce bandeau selon les surfaces, et rogne parfois les côtés :
    le dessin et le texte tiennent donc loin des bords.
    """
    img = Image.new("RGBA", (1024, 500))
    fond_nuit(img)
    dessiner_marque(img, 260, 270, 250)

    d = ImageDraw.Draw(img)
    d.text((440, 190), "Agora", font=police(92), fill=BLANC)
    d.text((444, 302), "Vos agendas, ensemble.", font=police(36), fill=(178, 186, 235))
    return img


#: Déclaration de l'icône adaptative. Sans elle, Android 8+ rogne le PNG carré
#: et le pose dans une pastille blanche — ce qui cernerait d'un liseré clair
#: une icône dont tout le propos est le fond nuit.
ADAPTATIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""

COULEURS_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Le haut du dégradé dessiné par tools/store/make_store_assets.py :
         Android ne sait poser qu'une couleur pleine derrière une icône
         adaptative. -->
    <color name="ic_launcher_background">#1A1B3A</color>
</resources>
"""

#: Écran de démarrage : le fond nuit de l'icône, et rien d'autre. Le dessin
#: appartient à l'intro, qui prend le relais dès que Flutter démarre ; le
#: poser ici aussi ferait apparaître la marque deux fois.
DEMARRAGE_XML = """<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/ic_launcher_background" />
</layer-list>
"""


def ecrire(chemin: Path, contenu: str) -> None:
    chemin.parent.mkdir(parents=True, exist_ok=True)
    chemin.write_text(contenu, encoding="utf-8", newline="\n")


def main() -> int:
    STORE.mkdir(parents=True, exist_ok=True)

    # 512 x 512, sans transparence : le Play Store refuse un PNG à couche alpha.
    carre(512, SUR_PLEINE).convert("RGB").save(STORE / "icon-512.png")
    bandeau().convert("RGB").save(STORE / "feature-1024x500.png")

    for densite, taille in MIPMAPS.items():
        dossier = RES / f"mipmap-{densite}"
        dossier.mkdir(parents=True, exist_ok=True)
        masque_arrondi(carre(taille, SUR_PLEINE)).save(dossier / "ic_launcher.png")
        # L'avant-plan d'une icône adaptative est dessiné sur un carré dont
        # Android ne montre qu'une partie : il fait 108 dp pour 72 dp visibles.
        adaptative = int(taille * 108 / 48)
        carre(adaptative, SUR_ADAPTATIVE, transparent=True).save(
            dossier / "ic_launcher_foreground.png"
        )

    ecrire(RES / "mipmap-anydpi-v26" / "ic_launcher.xml", ADAPTATIVE_XML)
    ecrire(RES / "values" / "ic_launcher_background.xml", COULEURS_XML)
    for variante in ("drawable", "drawable-v21"):
        ecrire(RES / variante / "launch_background.xml", DEMARRAGE_XML)

    print(f"ecrit : {STORE.relative_to(RACINE)}/ et {RES.relative_to(RACINE)}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

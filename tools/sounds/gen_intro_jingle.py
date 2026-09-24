"""Génère le jingle de l'écran d'introduction d'Agora.

**Un script plutôt qu'un fichier déposé.** Un son se refait — une note qui
traîne, un volume qui gêne sur haut-parleur de téléphone, une battue qu'on
déplace dans l'animation. Le script le régénère à l'identique ; un WAV figé
oblige à rouvrir un éditeur et à retrouver les valeurs de départ.

**Le rythme est celui de l'animation, pas l'inverse.** Une note par geste :
les trois agendas qui se posent l'un après l'autre, l'accord où ils se
rejoignent, le créneau libre qui s'allume, et le mot qui monte. Déplacer une
battue ici sans la déplacer dans l'intro désynchronise le tout, et cela ne
s'entend qu'à l'oreille — d'où [BATTUES], seule source des deux côtés.

**Six notes, comme DewDrop et DeckHand, et c'est délibéré.** Les trois
applications partagent une grammaire : une intro d'environ 2,2 s, six notes,
le logo qui apparaît dedans. Ce qui change est la couleur, et elle doit dire
le produit. DewDrop monte un arpège de do majeur en onde carrée 8-bit —
cristallin, aérien. DeckHand descend sur du bois — sol mixolydien, corde
pincée. Agora **converge** : trois notes séparées (ré, fa dièse, la — une par
membre), puis les trois ensemble, et c'est tout le sujet de l'app. Trois voix
qui deviennent un accord.

**Le timbre est une cloche douce, pas une corde ni un carré.** Les cloches
n'ont pas des harmoniques entières : leurs partiels sont légèrement décalés
(voir [PARTIELS]), et c'est ce décalage qui produit le halo métallique. Les
coefficients ne sont donc pas un réglage de volume mais la description d'un
instrument : les toucher change la cloche, pas son intensité.

Usage :

    python tools/sounds/gen_intro_jingle.py
    ffplay -autoexit -nodisp app/assets/audio/agora_intro.mp3   # pour écouter

Écrit `app/assets/audio/agora_intro.mp3` (et garde le WAV si ffmpeg manque).
Dépend de `numpy`.
"""

from __future__ import annotations

import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np

SR = 44100

RACINE = Path(__file__).resolve().parents[2]
SORTIE = RACINE / "app" / "assets" / "audio"
NOM = "agora_intro"

#: Les six battues de l'animation, en secondes depuis le premier trait posé.
#:
#: **Jumelle de `BATTUES` dans `tools/mockups/agora_intro.html`**, et plus tard
#: de `IntroTiming` côté Dart. L'intro démarre le son avec le premier trait ;
#: ces valeurs sont donc relatives à cet instant, pas au début de l'écran.
BATTUES = [0.00, 0.30, 0.60, 0.90, 1.10, 1.40]

#: Durée de chaque note. La dernière tient pendant que le mot monte en fondu.
DUREES = [0.32, 0.32, 0.32, 0.40, 0.30, 1.10]

#: Ré majeur. Les trois premières notes sont les trois membres du groupe, dans
#: l'ordre où leurs agendas se posent ; la quatrième les superpose — c'est le
#: seul moment de l'intro où les trois sonnent ensemble, et il tombe sur le
#: geste où les trois colonnes se rejoignent. La cinquième (si) ouvre : c'est
#: la sixte, elle sonne comme une question qu'on pose au groupe. La dernière
#: répond à l'octave.
VOIX = [
    ["D4"],
    ["F#4"],
    ["A4"],
    ["D4", "F#4", "A4"],
    ["B4"],
    ["D5", "A4"],
]

#: Basse tenue sous les six notes. Sans elle, les cloches flottent sans sol.
BASSE = "D2"

#: Volumes calés à l'oreille. La mélodie porte ; la basse et le souffle ne
#: s'entendent pas séparément — ils s'entendent quand on les retire.
VOL_VOIX, VOL_SOUFFLE, VOL_BASSE = 0.085, 0.020, 0.060

#: Au-delà, le halo métallique devient sifflant au casque.
COUPURE_HZ = 6000

#: Rangs d'une cloche : (multiple de la fondamentale, poids, décroissance).
#:
#: Les multiples ne sont pas entiers — 2,76 et 5,40 sont relevés sur les
#: partiels d'une cloche tubulaire. C'est ce décalage qui fait la cloche ; avec
#: 2, 3, 4 on obtient un orgue. Les rangs hauts s'éteignent plus vite, sinon la
#: note siffle longtemps après avoir été jouée.
PARTIELS = [(1.00, 1.00, 2.2), (2.00, 0.42, 3.0), (2.76, 0.26, 4.2),
            (4.07, 0.14, 5.6), (5.40, 0.07, 7.0)]

DEMI_TONS = {
    "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
    "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
}


def hauteur(nom: str) -> float:
    """Fréquence d'une note nommée. `A4` vaut 440 Hz."""
    note, octave = nom[:-1], int(nom[-1])
    return 440.0 * 2 ** ((DEMI_TONS[note] + 12 * (octave - 4) - 9) / 12)


def cloche(freq: float, duree: float, chaleur: float = 1.0) -> np.ndarray:
    """Une cloche douce : partiels inharmoniques, rangs hauts éteints d'abord.

    [chaleur] allonge la décroissance — au-dessus de 1 la note traîne, ce qui
    convient à la basse, jamais aux trois premières notes : elles doivent se
    poser distinctement, sinon on n'entend plus trois membres mais une nappe.
    """
    t = np.arange(int(duree * SR)) / SR
    voix = np.zeros_like(t)
    for multiple, poids, declin in PARTIELS:
        partiel = freq * multiple
        if partiel > SR / 2:
            break
        voix += poids * np.exp(-t * declin / chaleur) * np.sin(
            2 * np.pi * partiel * t + multiple
        )
    # Attaque courte mais pas nulle : à zéro, le haut-parleur d'un téléphone
    # claque.
    return voix * np.clip(t / 0.006, 0, 1)


def souffle(freq: float, duree: float) -> np.ndarray:
    """Un sous-corps sinus très doux : le feutre sous le métal."""
    t = np.arange(int(duree * SR)) / SR
    return np.sin(2 * np.pi * freq * t) * np.exp(-t * 2.4) * np.clip(t / 0.01, 0, 1)


def pose(buffer: np.ndarray, voix: np.ndarray, debut: float, volume: float) -> None:
    """Mélange [voix] dans [buffer] à partir de [debut]. Déborde sans lever."""
    i = int(debut * SR)
    fin = min(len(buffer), i + len(voix))
    if fin > i:
        buffer[i:fin] += volume * voix[: fin - i]


def reverb(x: np.ndarray, humide: float = 0.24) -> np.ndarray:
    """Réverbération de Schroeder légère, en peignes à rétroaction.

    Une place publique, pas une cathédrale : au-delà de 0,3 les six notes se
    confondent et la convergence ne s'entend plus.
    """
    sortie = x.copy()
    for retard_s, retour in ((0.0297, 0.80), (0.0371, 0.77),
                             (0.0411, 0.74), (0.0437, 0.71)):
        d = int(retard_s * SR)
        peigne = x.copy()
        for i in range(d, len(peigne)):
            peigne[i] += retour * peigne[i - d]
        sortie += peigne * humide * 0.25
    return sortie


def passe_bas(x: np.ndarray, coupure: float = COUPURE_HZ) -> np.ndarray:
    """Un pôle, pour ôter le sifflant des partiels hauts."""
    a = np.exp(-2 * np.pi * coupure / SR)
    y = np.zeros_like(x)
    accumule = 0.0
    for i, v in enumerate(x):
        accumule = (1 - a) * v + a * accumule
        y[i] = accumule
    return y


def construire() -> np.ndarray:
    """Le jingle entier, normalisé sous la saturation."""
    total = BATTUES[-1] + DUREES[-1] + 0.8
    buffer = np.zeros(int(SR * total))

    for notes, debut, duree in zip(VOIX, BATTUES, DUREES):
        # L'accord de la quatrième battue tient trois notes : les répartir au
        # même volume le ferait sonner trois fois plus fort que les autres.
        volume = VOL_VOIX / max(1, len(notes)) ** 0.5
        for nom in notes:
            pose(buffer, cloche(hauteur(nom), duree), debut, volume)
        pose(buffer, souffle(hauteur(notes[0]), duree * 0.6), debut, VOL_SOUFFLE)

    # La basse entre avec le premier agenda et tient jusqu'au mot.
    pose(buffer, cloche(hauteur(BASSE), 2.4, chaleur=3.0), 0.0, VOL_BASSE)

    buffer = passe_bas(reverb(buffer))
    crete = float(np.max(np.abs(buffer)))
    return buffer * (0.85 / max(crete, 1e-6))


def ecrire_wav(chemin: Path, echantillons: np.ndarray) -> None:
    with wave.open(str(chemin), "w") as sortie:
        sortie.setnchannels(1)
        sortie.setsampwidth(2)
        sortie.setframerate(SR)
        borne = np.clip(echantillons, -1.0, 1.0)
        sortie.writeframes((borne * 32767).astype("<i2").tobytes())


def main() -> int:
    SORTIE.mkdir(parents=True, exist_ok=True)
    wav = SORTIE / f"{NOM}.wav"
    ecrire_wav(wav, construire())

    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        print(f"ffmpeg absent - le WAV reste seul : {wav}")
        return 0

    mp3 = SORTIE / f"{NOM}.mp3"
    subprocess.run(
        [ffmpeg, "-y", "-loglevel", "error", "-i", str(wav), "-b:a", "128k", str(mp3)],
        check=True,
    )
    # **Le WAV est un intermédiaire, pas un livrable** : le garder ferait
    # entrer 300 Kio inutiles dans l'APK, pour un son que personne ne compare.
    wav.unlink()
    print(f"ecrit : {mp3.relative_to(RACINE)} ({mp3.stat().st_size // 1024} Kio)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

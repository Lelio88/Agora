"""Génère le jingle de l'écran d'introduction d'Agora.

**Un script plutôt qu'un fichier déposé.** Un son se refait — une note qui
traîne, un volume qui gêne sur haut-parleur de téléphone, une battue qu'on
déplace dans l'animation. Le script le régénère à l'identique ; un WAV figé
oblige à rouvrir un éditeur et à retrouver les valeurs de départ.

**Chaque application a son univers, et celui d'Agora est la quinte ouverte.**
DewDrop monte un arpège de do majeur en onde carrée 8-bit, cristallin.
DeckHand descend sur du bois, en sol mixolydien. Agora n'a **aucune tierce** :
ré, la, mi — des quintes empilées. C'est ce qui lui donne sa couleur : une
sonorité ouverte, ni majeure ni mineure, qui ne prend pas parti. Cinq autres
mélodies ont été comparées à l'écoute avant celle-ci — une descente, un appel
et sa réponse, une montée chromatique, un carillon lent, un motif rapide.

**Les trois premières notes montent séparément, la quatrième les superpose.**
C'est la seule fois où les trois sonnent ensemble, et cela tombe sur le geste
de l'animation où les trois agendas se rejoignent. La cinquième note (si)
ouvre, la dernière répond à l'octave.

**Le timbre n'est pas arrêté.** Celui-ci — une corde frappée feutrée — est
celui sur lequel la mélodie a été retenue ; l'instrument définitif se choisira
ensuite, sans toucher aux hauteurs. Les coefficients de [corde_feutree] sont
donc la seule partie de ce fichier qu'on peut remplacer sans rien recalculer.

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

#: Les six gestes de l'animation, en secondes depuis la première note.
#:
#: **Jumelle de `battues` dans `app/lib/src/features/intro/presentation/`** et
#: de `BATTUES` dans la maquette. Déplacer l'une sans les autres désynchronise
#: l'intro, et cela ne s'entend qu'à l'oreille.
BATTUES = [0.0, 0.30, 0.60, 0.90, 1.10, 1.40]

#: Durée de chaque note. La dernière tient pendant que le mot monte en fondu.
DUREES = [0.30, 0.30, 0.30, 0.48, 0.28, 1.20]

#: Ré, la, mi : deux quintes empilées, jouées une par une, puis ensemble.
#:
#: **L'absence de tierce est le sujet, pas un oubli.** Une tierce dirait
#: majeur (joyeux) ou mineur (triste) ; la quinte ne dit ni l'un ni l'autre,
#: elle ouvre. Ajouter un fa dièse ici rendrait le jingle plus consonant et lui
#: ferait perdre exactement ce qui le distingue des deux autres applications.
VOIX = [
    ["D4"],
    ["A4"],
    ["E5"],
    ["D4", "A4", "E5"],
    ["B4"],
    ["D5", "A4"],
]

#: Basse tenue sous les six notes. Sans elle, les quintes flottent sans sol.
BASSE = "D2"

#: Volumes calés à l'oreille. La mélodie porte ; la basse et le souffle ne
#: s'entendent pas séparément — ils s'entendent quand on les retire.
VOL_VOIX, VOL_SOUFFLE, VOL_BASSE = 0.085, 0.020, 0.060

#: Au-delà, les harmoniques hautes deviennent sifflantes au casque.
COUPURE_HZ = 6000

DEMI_TONS = {
    "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
    "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
}


def hauteur(nom: str) -> float:
    """Fréquence d'une note nommée. `A4` vaut 440 Hz."""
    note, octave = nom[:-1], int(nom[-1])
    return 440.0 * 2 ** ((DEMI_TONS[note] + 12 * (octave - 4) - 9) / 12)


def corde_feutree(freq: float, duree: float, chaleur: float = 1.0) -> np.ndarray:
    """Une corde frappée, feutrée : harmoniques entières dont les rangs hauts
    s'éteignent d'abord, très légèrement étirées vers l'aigu comme sur un vrai
    piano.

    [chaleur] allonge la décroissance — au-dessus de 1 la note traîne, ce qui
    convient à la basse, jamais aux trois premières : elles doivent se poser
    distinctement, sinon on n'entend plus trois notes mais une nappe.
    """
    t = np.arange(int(duree * SR)) / SR
    voix = np.zeros_like(t)
    for rang in range(1, 7):
        # L'inharmonicité d'une corde réelle : le rang n n'est pas exactement
        # n fois le fondamental. Sans ce décalage, on obtient un orgue.
        partiel = freq * rang * (1 + 0.0004 * rang * rang)
        if partiel > SR / 2:
            break
        declin = 1.8 + rang * 0.9
        voix += (1.0 / rang ** 1.4) * np.exp(-t * declin / chaleur) * np.sin(
            2 * np.pi * partiel * t + rang
        )
    # Attaque courte mais pas nulle : à zéro, le haut-parleur d'un téléphone
    # claque.
    return voix * np.clip(t / 0.008, 0, 1)


def souffle(freq: float, duree: float) -> np.ndarray:
    """Un sous-corps sinus très doux : le feutre sous la corde."""
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

    Une place publique, pas une cathédrale : au-delà de 0,3 les notes se
    confondent et l'empilement des quintes ne s'entend plus.
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
    """Un pôle, pour ôter le sifflant des harmoniques hautes."""
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
        # L'accord de la quatrième battue tient trois notes : les jouer au même
        # volume que les autres le ferait sonner trois fois plus fort.
        volume = VOL_VOIX / max(1, len(notes)) ** 0.5
        for nom in notes:
            pose(buffer, corde_feutree(hauteur(nom), duree), debut, volume)
        pose(buffer, souffle(hauteur(notes[0]), duree * 0.6), debut, VOL_SOUFFLE)

    # La basse entre avec la première note et tient jusqu'au mot.
    pose(buffer, corde_feutree(hauteur(BASSE), 2.4, chaleur=3.0), 0.0, VOL_BASSE)

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

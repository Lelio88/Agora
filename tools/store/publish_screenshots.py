"""Remplace les captures « téléphone » de la fiche Play d'Agora par celles de
`app/store/` (01-…png à 08-…png, dans l'ordre de leur nom).

Pourquoi un script : les captures se refont à chaque changement d'interface
(voir `app/store/README.md`), et les déposer une à une dans la Play Console,
dans le bon ordre et pour chaque langue, est l'étape qu'on finit par sauter.

Choix non évidents :
- tout passe par une *édition* Play, comme l'envoi d'un bundle : on vide les
  captures de la langue, on envoie les nouvelles, on valide, puis on
  publie l'édition. Une erreur en cours de route abandonne l'édition, et la
  fiche en ligne ne bouge pas ; `--dry-run` s'arrête juste avant de publier ;
- seules les langues qui ont déjà une fiche sont touchées (`--language` pour
  en viser une seule) : les captures sont en français, mais une fiche
  anglaise sans captures resterait sans rien ;
- l'authentification et les messages d'erreur viennent de
  `tools/release/publish_play.py` (même compte de service, même coffre) :
  ce fichier-là est commun à toutes les apps et ne doit pas diverger.

Usage :

    python tools/store/publish_screenshots.py --dry-run
    python tools/store/publish_screenshots.py
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RACINE / "tools" / "release"))
import publish_play  # noqa: E402  (le chemin doit être posé avant l'import)

PAQUET = "app.agora"
CAPTURES = RACINE / "app" / "store"

#: Play n'en accepte pas davantage par type d'appareil.
MAX_CAPTURES = 8


def captures() -> list[Path]:
    """Les captures à envoyer, dans l'ordre de leur numéro."""
    fichiers = sorted(CAPTURES.glob("0[1-9]-*.png"))
    if not 2 <= len(fichiers) <= MAX_CAPTURES:
        publish_play.fail(
            f"{len(fichiers)} captures dans {CAPTURES} : Play en veut de 2 à "
            f"{MAX_CAPTURES}."
        )
    return fichiers


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--language", help="une seule langue de fiche (ex. fr-FR)")
    parser.add_argument("--credentials", help="JSON du compte de service")
    parser.add_argument(
        "--dry-run", action="store_true", help="tout, sauf publier l'édition"
    )
    args = parser.parse_args()

    candidats = publish_play.credential_candidates(str(RACINE))
    compte = args.credentials or next(
        (c for c in candidats if Path(c).is_file()), candidats[0]
    )
    sess = publish_play.session(compte)
    api, upload = publish_play.API, publish_play.UPLOAD
    fichiers = captures()

    edition = publish_play.check(
        sess.post(f"{api}/{PAQUET}/edits"), "création de l'édition"
    )["id"]
    base = f"{api}/{PAQUET}/edits/{edition}"
    publiee = False
    try:
        fiches = publish_play.check(sess.get(f"{base}/listings"), "fiches")
        langues = [f["language"] for f in fiches.get("listings", [])]
        if args.language:
            if args.language not in langues:
                publish_play.fail(
                    f"Pas de fiche {args.language} (fiches : {', '.join(langues)})."
                )
            langues = [args.language]
        print(f"  fiches     {', '.join(langues)}")
        print(f"  captures   {', '.join(f.name for f in fichiers)}")
        for langue in langues:
            avant = publish_play.check(
                sess.get(f"{base}/listings/{langue}/phoneScreenshots"),
                f"captures {langue}",
            )
            print(f"  → {langue} : {len(avant.get('images', []))} captures remplacées")
            publish_play.check(
                sess.delete(f"{base}/listings/{langue}/phoneScreenshots"),
                f"suppression des captures {langue}",
            )
            for fichier in fichiers:
                publish_play.check(
                    sess.post(
                        f"{upload}/{PAQUET}/edits/{edition}/listings/{langue}"
                        "/phoneScreenshots?uploadType=media",
                        data=fichier.read_bytes(),
                        headers={"Content-Type": "image/png"},
                    ),
                    f"envoi de {fichier.name} ({langue})",
                )
        publish_play.check(sess.post(f"{base}:validate"), "validation")
        print("  → validation OK")
        if args.dry_run:
            print("\n[i] --dry-run : édition abandonnée, la fiche ne change pas.")
            return
        publish_play.check(sess.post(f"{base}:commit"), "publication")
        publiee = True
        print("\n[OK] Captures publiées sur la fiche.")
    finally:
        if not publiee:
            sess.delete(base)


if __name__ == "__main__":
    main()

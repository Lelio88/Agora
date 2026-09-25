"""Change le mot de passe du compte de revue du Play Store.

À lancer chaque fois que le mot de passe a pu être vu : affiché par un script,
collé dans une conversation, laissé dans un journal de session. Un mot de
passe qu'on n'est plus sûr de garder pour soi se remplace — il ne se discute
pas.

Le nouveau est tiré au sort, posé par la clé de service, et écrit dans
`../.agora-secrets/play-review.env`. Il ne s'affiche nulle part : c'est tout
l'intérêt.

Usage :

    python tools/store/rotate_review_password.py
"""

from __future__ import annotations

import re
import secrets
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import seed_demo  # noqa: E402
import seed_review  # noqa: E402


def main() -> int:
    coffre = seed_review.secrets_du_coffre()
    api = coffre['API_URL'].strip()
    if '127.0.0.1' in api or 'localhost' in api:
        raise SystemExit(f'Le coffre ne pointe pas la production : {api}')

    seed_demo.configurer(api, coffre['ANON_KEY'].strip(),
                         coffre['SERVICE_ROLE_KEY'].strip())
    seed_review.JWT_SECRET = coffre['JWT_SECRET'].strip()

    adresse = seed_review.COMPTES['principal'][0]
    uid = seed_review.identifiant(adresse, seed_demo.SECRET)

    nouveau = secrets.token_urlsafe(18) + '7a'
    seed_demo.call(
        f'/auth/v1/admin/users/{uid}',
        {'password': nouveau},
        key=seed_demo.SECRET,
        method='PUT',
    )

    fichier = seed_review.COFFRE / 'play-review.env'
    texte = fichier.read_text(encoding='utf-8') if fichier.exists() else (
        '# Compte de revue du Play Store.\n'
        f'PLAY_REVIEW_EMAIL={adresse}\n'
        'PLAY_REVIEW_PASSWORD=\n'
    )
    texte = re.sub(r'^PLAY_REVIEW_PASSWORD=.*$',
                   f'PLAY_REVIEW_PASSWORD={nouveau}', texte, flags=re.M)
    fichier.write_text(texte, encoding='utf-8', newline='\n')

    print(f'Mot de passe remplacé pour {adresse}.')
    print(f'Le nouveau est dans {fichier} — il n\'est pas affiché ici.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

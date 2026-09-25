"""Crée, **en production**, le compte que les relecteurs du Play Store
utiliseront pour examiner Agora.

**Pourquoi un compte préparé plutôt qu'une inscription.** Google refuse une
application dont il ne peut pas voir toutes les sections, et ses relecteurs ne
créent pas de comptes. Or Agora est entièrement derrière une connexion, et
l'inscription envoie un code à six chiffres par e-mail : un relecteur devrait
relever une boîte mail pour entrer. Ce script crée donc le compte **déjà
confirmé**, côté serveur, par la clé de service.

**Et avec du contenu, pas seulement un compte.** Un compte vide montre un
agenda vide et un écran « aucun groupe » : le relecteur ne verrait ni l'agenda
de groupe, ni les créneaux communs, ni les réponses à un rendez-vous, et
conclurait que l'application ne fait rien. La scène est celle de
`seed_demo.py`, aux mêmes proportions.

**Il écrit dans la base de production.** Il est donc idempotent : relancé, il
constate que le compte a déjà son groupe et s'arrête sans rien dupliquer. Le
mot de passe est tiré au sort, jamais inventé, et va dans le coffre — il ne
transite ni par un terminal ni par une conversation.

**Les jetons sont fabriqués, pas obtenus par connexion.** La production exige
un CAPTCHA sur `/auth/v1/token`, et c'est exactement ce qu'on veut : un script
ne doit pas pouvoir s'y connecter. Poser la scène demande pourtant d'agir *au
nom de* chaque compte, puisque `create_group` et les autres fonctions lisent
`auth.uid()`. On signe donc un jeton d'une heure avec le secret JWT de
l'instance, celui-là même dont PostgREST se sert pour vérifier les jetons. Le
mot de passe du compte, lui, reste le seul chemin d'entrée par l'application —
CAPTCHA compris, comme pour n'importe qui.

Usage :

    python tools/store/seed_review.py

Lit `../.agora-secrets/supabase.env` (API_URL, ANON_KEY, SERVICE_ROLE_KEY) et
écrit `../.agora-secrets/play-review.env`.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import secrets
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import seed_demo  # noqa: E402  (le chemin doit être posé avant l'import)

RACINE = Path(__file__).resolve().parents[2]
COFFRE = RACINE.parent / '.agora-secrets'

#: Le domaine d'Agora, pas une adresse personnelle : ces identifiants partent
#: chez Google, et rien n'oblige à leur confier une boîte qui sert à autre
#: chose. Aucun e-mail n'est envoyé — les comptes naissent confirmés.
DOMAINE = 'agora.heianenterprise.com'
JWT_SECRET = ''

COMPTES = {
    'principal': (f'play-review@{DOMAINE}', 'Compte de revue'),
    'lea': (f'lea.demo@{DOMAINE}', 'Léa'),
    'malo': (f'malo.demo@{DOMAINE}', 'Malo'),
    'ines': (f'ines.demo@{DOMAINE}', 'Inès'),
}


def secrets_du_coffre() -> dict[str, str]:
    fichier = COFFRE / 'supabase.env'
    if not fichier.exists():
        raise SystemExit(f'Coffre introuvable : {fichier}')
    return dict(
        re.findall(r'^([A-Z_]+)=(.*)$', fichier.read_text(encoding='utf-8'), re.M)
    )


def forger(uid: str, email: str, secret_jwt: str) -> str:
    """Un jeton d'accès signé comme le ferait GoTrue, valable une heure."""
    def encode(donnees: dict) -> bytes:
        brut = json.dumps(donnees, separators=(',', ':')).encode()
        return base64.urlsafe_b64encode(brut).rstrip(b'=')

    maintenant = int(time.time())
    entete = encode({'alg': 'HS256', 'typ': 'JWT'})
    charge = encode({
        'sub': uid,
        'email': email,
        # `authenticated` et non `service_role` : la scène doit se poser sous
        # RLS, exactement comme le ferait l'application. Un script qui
        # contourne les règles ne prouve rien de ce que verra le relecteur.
        'role': 'authenticated',
        'aud': 'authenticated',
        'iat': maintenant,
        'exp': maintenant + 3600,
    })
    signature = base64.urlsafe_b64encode(
        hmac.new(secret_jwt.encode(), entete + b'.' + charge, hashlib.sha256).digest()
    ).rstrip(b'=')
    return b'.'.join([entete, charge, signature]).decode()


def identifiant(email: str, secret: str) -> str:
    """L'identifiant d'un compte déjà créé, retrouvé par son adresse."""
    page = 1
    while page < 20:
        reponse = seed_demo.call(
            f'/auth/v1/admin/users?page={page}&per_page=200', key=secret
        )
        utilisateurs = reponse.get('users', []) if isinstance(reponse, dict) else []
        for utilisateur in utilisateurs:
            if utilisateur.get('email') == email:
                return utilisateur['id']
        if len(utilisateurs) < 200:
            break
        page += 1
    raise SystemExit(f'Compte introuvable après création : {email}')


def compte_prepare(email: str, nom: str) -> str:
    """Crée le compte (confirmé) et rend un jeton fabriqué pour lui.

    Remplace `seed_demo.compte`, qui se connecte par mot de passe — impossible
    en production, où le CAPTCHA garde cette porte.
    """
    secret = seed_demo.SECRET
    uid = None
    try:
        cree = seed_demo.call(
            '/auth/v1/admin/users',
            {
                'email': email,
                'password': seed_demo.PASSWORD,
                'email_confirm': True,
                'user_metadata': {
                    'display_name': nom,
                    'locale': 'fr',
                    'timezone': 'Europe/Paris',
                },
            },
            key=secret,
        )
        uid = cree['id']
    except SystemExit as erreur:
        if 'email_exists' not in str(erreur):
            raise
    if uid is None:
        uid = identifiant(email, secret)
    return forger(uid, email, JWT_SECRET)


def deja_prepare(jeton: str) -> bool:
    """Le compte a-t-il déjà sa scène ? On regarde ses groupes, pas son
    existence : un compte peut exister sans que la scène ait été posée."""
    groupes = seed_demo.call('/rest/v1/groups?select=id', token=jeton)
    return bool(groupes)


def main() -> int:
    coffre = secrets_du_coffre()
    manquants = [
        cle for cle in ('API_URL', 'ANON_KEY', 'SERVICE_ROLE_KEY', 'JWT_SECRET')
        if not coffre.get(cle)
    ]
    if manquants:
        raise SystemExit(f'Coffre incomplet : {", ".join(manquants)}')

    api = coffre['API_URL'].strip()
    if '127.0.0.1' in api or 'localhost' in api:
        raise SystemExit(f'Le coffre ne pointe pas la production : {api}')

    # Un mot de passe tiré au sort. Il respecte la règle de l'app : des
    # lettres ET des chiffres (voir la validation des écrans de compte).
    mot_de_passe = secrets.token_urlsafe(18) + '7a'

    global JWT_SECRET
    JWT_SECRET = coffre['JWT_SECRET'].strip()

    seed_demo.configurer(api, coffre['ANON_KEY'].strip(),
                         coffre['SERVICE_ROLE_KEY'].strip())
    seed_demo.PASSWORD = mot_de_passe
    seed_demo.ADRESSES = COMPTES
    seed_demo.compte = compte_prepare

    adresse = COMPTES['principal'][0]
    print(f'Cible : {api}')

    jeton = compte_prepare(*COMPTES['principal'])
    if deja_prepare(jeton):
        print(
            f'{adresse} a déjà sa scène — rien à faire.\n'
            'Le mot de passe en vigueur est dans '
            f'{(COFFRE / "play-review.env")}.'
        )
        return 0

    seed_demo.main()

    (COFFRE / 'play-review.env').write_text(
        '# Compte de revue du Play Store, créé par tools/store/seed_review.py.\n'
        "# À coller dans « Accès à l'application » de la console Play.\n"
        f'PLAY_REVIEW_EMAIL={adresse}\n'
        f'PLAY_REVIEW_PASSWORD={mot_de_passe}\n'
        f'PLAY_REVIEW_COMPAGNONS={COMPTES["lea"][0]},{COMPTES["malo"][0]},'
        f'{COMPTES["ines"][0]}\n',
        encoding='utf-8',
        newline='\n',
    )
    print(
        f'Scène de revue prête pour {adresse}.\n'
        f'Identifiants écrits dans {(COFFRE / "play-review.env")} — '
        'ils ne sont pas affichés ici.'
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

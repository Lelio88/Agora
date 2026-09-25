"""Peuple la pile LOCALE d'une scène de démonstration, pour les captures de la
fiche Play Store.

Pourquoi un script : une capture se refait — un libellé qui change, une vue
qu'on ajoute, une traduction qui s'allonge. Rejouer la scène à l'identique vaut
mieux que de recomposer à la main des rendez-vous plausibles.

La scène raconte le produit en cinq écrans : mon agenda, l'agenda d'un groupe
où chacun partage ce qu'il veut, la recherche de créneau commun, un rdv proposé
avec ses réponses, et un agenda importé par lien iCal.

Deux groupes, pas un : c'est le seul moyen de montrer la promesse centrale —
Camille ouvre le détail à sa coloc et se contente de « occupé » avec le club
de rando. Le même agenda, deux niveaux de confidentialité.

Elle ne touche QUE la pile locale (127.0.0.1:55321). Les adresses sont en
`@demo.local` : aucun e-mail ne part.

Usage :

    supabase db reset && python tools/store/seed_demo.py
"""

from __future__ import annotations

import json
import subprocess
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

#: Cible et clés, posées par [configurer] plutôt que résolues à l'import :
#: `seed_review.py` vise la production, et n'a aucune raison d'exiger qu'une
#: pile locale tourne pour être importé.
API = ''
ANON = ''
SECRET = ''

PASSWORD = 'Demonstration2026'

#: Les comptes de la scène, dans l'ordre : le principal, puis ses compagnons.
#: `seed_review.py` les remplace par des adresses du domaine d'Agora.
ADRESSES = {
    'principal': ('camille@demo.local', 'Camille'),
    'lea': ('lea@demo.local', 'Léa'),
    'malo': ('malo@demo.local', 'Malo'),
    'ines': ('ines@demo.local', 'Inès'),
}


def configurer(api: str, anon: str, secret: str) -> None:
    """Pointe le script sur une pile. À appeler avant [main]."""
    global API, ANON, SECRET
    API, ANON, SECRET = api, anon, secret


def cles() -> tuple[str, str]:
    """Les clés de la pile locale, demandées à la CLI plutôt qu'écrites ici.

    **Aucune clé en dur, même locale.** Le dépôt est public, et la clé de
    service d'une pile de développement reste une clé de service : le scanner
    de GitHub la refuse, et il a raison — elle ouvre toutes les tables sans
    RLS. La lire ici a un second mérite : la scène se rejoue sur n'importe
    quelle machine, sans retoucher le script.
    """
    sortie = subprocess.run(
        ['supabase', 'status', '-o', 'json'],
        capture_output=True, text=True, shell=True,
    )
    if sortie.returncode != 0:
        raise SystemExit(
            "Pile locale introuvable. Lancer « supabase start » d'abord.\n"
            + sortie.stderr.strip()[:300]
        )
    etat = json.loads(sortie.stdout)
    return etat['ANON_KEY'], etat['SERVICE_ROLE_KEY']


# Lundi de la semaine courante, à minuit local (les vues d'agenda l'ouvrent).
TODAY = datetime.now()
MONDAY = (TODAY - timedelta(days=TODAY.weekday())).replace(
    hour=0, minute=0, second=0, microsecond=0
)


def at(day: int, hour: int, minute: int = 0) -> str:
    """Horodatage UTC d'un moment de la semaine affichée."""
    local = MONDAY + timedelta(days=day, hours=hour, minutes=minute)
    return local.astimezone(timezone.utc).isoformat()


def call(path, data=None, token=None, key=ANON, method=None):
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(API + path, data=body, method=method)
    req.add_header('apikey', key)
    req.add_header('Authorization', 'Bearer ' + (token or key))
    req.add_header('Content-Type', 'application/json')
    req.add_header('Prefer', 'return=representation')
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raise SystemExit(f'{path} → {e.code} {e.read().decode()[:200]}') from e


def compte(email: str, nom: str) -> str:
    """Crée le compte (confirmé) et rend son jeton de session. Rejouable :
    un compte déjà là est réutilisé tel quel."""
    try:
        call(
            '/auth/v1/admin/users',
            {
                'email': email,
                'password': PASSWORD,
                'email_confirm': True,
                'user_metadata': {
                    'display_name': nom,
                    'locale': 'fr',
                    'timezone': 'Europe/Paris',
                },
            },
            key=SECRET,
        )
    except SystemExit as erreur:
        if 'email_exists' not in str(erreur):
            raise
    session = call(
        '/auth/v1/token?grant_type=password', {'email': email, 'password': PASSWORD}
    )
    return session['access_token']


def agenda_perso(token: str) -> str:
    calendars = call('/rest/v1/calendars?select=id,group_id', token=token)
    return next(c['id'] for c in calendars if c['group_id'] is None)


def rdv(token, calendar_id, titre, debut, fin, lieu=None, visibilite=None):
    call(
        '/rest/v1/events',
        {
            'calendar_id': calendar_id,
            'title': titre,
            'location': lieu,
            'starts_at': debut,
            'ends_at': fin,
            'all_day': False,
            'timezone': 'Europe/Paris',
            'visibility': visibilite,
        },
        token=token,
    )


def groupe_avec(nom, hote, membres):
    """Crée le groupe, y fait entrer chacun au niveau de partage voulu, et
    rend son identifiant. `membres` : [(jeton, niveau)], l'hôte compris —
    le créateur entre en « busy » par défaut, on le repositionne ensuite."""
    groupe = call('/rest/v1/rpc/create_group', {'p_name': nom}, token=hote)
    code = call('/rest/v1/rpc/create_invite', {'p_group_id': groupe}, token=hote)
    for jeton, niveau in membres:
        if jeton is not hote:
            call(
                '/rest/v1/rpc/join_group',
                {'p_code': code, 'p_share_level': niveau},
                token=jeton,
            )
        else:
            call(
                f'/rest/v1/group_members?group_id=eq.{groupe}&user_id=eq.'
                + call('/auth/v1/user', token=jeton)['id'],
                {'share_level': niveau},
                token=jeton,
                method='PATCH',
            )
    return groupe


def main() -> None:
    camille = compte(*ADRESSES['principal'])
    lea = compte(*ADRESSES['lea'])
    malo = compte(*ADRESSES['malo'])
    ines = compte(*ADRESSES['ines'])

    # --- Deux groupes, deux niveaux de confidentialité pour le MÊME agenda.
    coloc = groupe_avec(
        'Coloc',
        camille,
        [(camille, 'details'), (lea, 'details'), (malo, 'busy')],
    )
    groupe_avec(
        'Club de rando',
        camille,
        [(camille, 'busy'), (ines, 'details'), (malo, 'busy')],
    )

    # --- La semaine de Camille. Les horaires tiennent volontairement dans une
    # même fenêtre (9 h - 21 h) : une capture d'écran de téléphone n'en montre
    # pas davantage d'un seul tenant.
    perso = agenda_perso(camille)
    call(
        f'/rest/v1/calendars?id=eq.{perso}',
        {'name': 'Perso'},
        token=camille,
        method='PATCH',
    )
    rdv(camille, perso, 'Cours de dessin', at(1, 18), at(1, 20), 'Atelier Rive')
    rdv(camille, perso, 'Dentiste', at(2, 9), at(2, 10), visibilite='busy')
    rdv(camille, perso, 'Déjeuner avec Sam', at(3, 12, 30), at(3, 14), 'Le Comptoir')
    rdv(camille, perso, 'Piscine', at(4, 7, 30), at(4, 8, 30))

    # --- Celle des autres, vue depuis le groupe.
    lea_perso, malo_perso = agenda_perso(lea), agenda_perso(malo)
    rdv(lea, lea_perso, 'Répétition', at(1, 19), at(1, 21, 30), 'Studio B')
    rdv(lea, lea_perso, 'Cours de chant', at(1, 14), at(1, 15, 30))
    rdv(lea, lea_perso, 'Garde', at(3, 8), at(3, 18), visibilite='busy')
    rdv(malo, malo_perso, 'Travail', at(1, 9), at(1, 17))
    rdv(malo, malo_perso, 'Entraînement', at(4, 18, 30), at(4, 20))

    # --- Le rdv proposé au groupe, et ses réponses.
    calendriers = call(
        f'/rest/v1/calendars?select=id&group_id=eq.{coloc}', token=camille
    )
    agenda_groupe = calendriers[0]['id']
    evenement = call(
        '/rest/v1/events',
        {
            'calendar_id': agenda_groupe,
            'title': 'Raclette',
            'location': 'À la maison',
            'starts_at': at(5, 20),
            'ends_at': at(5, 23),
            'all_day': False,
            'timezone': 'Europe/Paris',
        },
        token=camille,
    )[0]
    for token, reponse in ((camille, 'yes'), (lea, 'yes'), (malo, 'maybe')):
        call(
            '/rest/v1/rpc/respond_to_event',
            {
                'p_event_id': evenement['id'],
                'p_occurrence_start': None,
                'p_status': reponse,
            },
            token=token,
        )

    # --- Un agenda importé : écrit en direct, faute de flux iCal à joindre
    # depuis une machine de développement.
    importe = call(
        '/rest/v1/calendars',
        {
            'owner_id': call('/auth/v1/user', token=camille)['id'],
            'name': 'Cours (fac)',
            'color': '#00897B',
            'kind': 'ics',
            'last_synced_at': datetime.now(timezone.utc).isoformat(),
        },
        key=SECRET,
    )[0]
    for jour, heure, titre in ((0, 10, 'Amphi — Droit'), (2, 14, 'TD — Statistiques')):
        call(
            '/rest/v1/events',
            {
                'calendar_id': importe['id'],
                'title': titre,
                'starts_at': at(jour, heure),
                'ends_at': at(jour, heure + 2),
                'all_day': False,
                'timezone': 'Europe/Paris',
                'source_uid': f'demo-{jour}-{heure}',
            },
            key=SECRET,
        )

    # **Le mot de passe ne s'imprime pas.** Il est fixe et sans valeur pour la
    # pile locale, mais `seed_review.py` réutilise cette fonction avec un mot
    # de passe de production : l'afficher le déverserait dans un terminal, un
    # journal de session et tout ce qui les relit.
    print('Scène prête —', ADRESSES['principal'][0])
    print('Semaine affichée : du', MONDAY.date(), 'au', (MONDAY + timedelta(days=6)).date())


if __name__ == '__main__':
    configurer('http://127.0.0.1:55321', *cles())
    main()

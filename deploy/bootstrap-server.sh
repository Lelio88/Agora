#!/bin/sh
# Prépare un serveur pour Agora. Idempotent : se relance sans rien casser.
#
# Usage, depuis le poste de travail (le script s'installe depuis son dossier) :
#   scp -r deploy root@<serveur>:/tmp/agora-deploy
#   ssh root@<serveur> sh /tmp/agora-deploy/bootstrap-server.sh
#
# Ce qu'il fait :
#   1. crée /opt/agora (compose, init/, caddy/, email/, web/, migrations/) ;
#   2. génère .env avec des secrets aléatoires s'il n'existe pas — jamais
#      écrasé ensuite, c'est le seul fichier qui ne vienne pas de la CI ;
#   3. vérifie que les ports de la boucle locale (9401-9404) sont libres ;
#   4. branche le vhost dans le Caddyfile de l'hôte (import), après validation ;
#   5. déclare la base dans le script de sauvegarde — une base absente de sa
#      liste n'est pas sauvegardée, en silence ;
#   6. signale ce qui reste manuel.
#
# À lancer APRÈS avoir pointé le DNS (agora. et api.agora.) sur ce serveur :
# Caddy demande les certificats dès le rechargement.
#
# Le déploiement lui-même (images, migrations, up, application web) est fait
# par la CI (.github/workflows/deploy.yml).

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
DEST=/opt/agora
CADDYFILE=/etc/caddy/Caddyfile
IMPORT_LINE="import $DEST/caddy/agora.caddy"
BACKUP_SCRIPT=/usr/local/bin/backup-postgres.sh
# conteneur:rôle:nom — rôle postgres : supabase_admin exige un mot de passe
# même par la socket locale.
BACKUP_ENTRY="agora_db:postgres:agora"

echo "== Agora : préparation de $DEST"
mkdir -p "$DEST/init" "$DEST/caddy" "$DEST/email" "$DEST/web" "$DEST/migrations"
install -m 644 "$HERE/docker-compose.prod.yml" "$DEST/docker-compose.yml"
install -m 644 "$HERE/init/zzz-roles.sql" "$DEST/init/zzz-roles.sql"
install -m 755 "$HERE/migrate.sh" "$DEST/migrate.sh"
install -m 644 "$HERE/caddy/agora.caddy" "$DEST/caddy/agora.caddy"

if [ -f "$DEST/.env" ]; then
    echo "   .env existant conservé"
else
    umask 077
    sh "$HERE/gen-secrets.sh" "$HERE/production.env.example" > "$DEST/.env"
    chmod 600 "$DEST/.env"
    echo "   .env créé, secrets aléatoires générés"
fi

# Ports publiés sur la boucle locale par le compose : un port déjà pris
# ferait échouer le démarrage du service concerné, et lui seul.
if [ ! -f "$DEST/.ports-checked" ]; then
    for port in 9401 9402 9403 9404; do
        if ss -ltnH "sport = :$port" | grep -q .; then
            echo "   ⚠ port $port déjà utilisé : changer le compose et le vhost avant de déployer"
            exit 1
        fi
    done
    : > "$DEST/.ports-checked"
    echo "   ports 9401-9404 libres"
fi

# Le journal d'accès doit exister ET appartenir à l'utilisateur de Caddy
# AVANT le rechargement : créé en root par « caddy validate », il serait
# refusé et Caddy rejetterait toute la configuration (piège vécu avec Lumis).
# Caddy < 2.7.5 AJOUTE le X-Forwarded-For du client au lieu de le remplacer :
# n'importe qui pourrait alors forger son adresse et contourner les limites
# par client de GoTrue (codes, connexions).
CADDY_VERSION=$(caddy version 2>/dev/null | head -1 | sed -E 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
case "$CADDY_VERSION" in
    2.[0-6].* | 2.7.[0-4])
        echo "   ⚠ Caddy $CADDY_VERSION : mettre à jour (≥ 2.7.5) avant d'ouvrir l'app, sinon"
        echo "     un client peut forger son X-Forwarded-For et contourner les limites de GoTrue."
        ;;
    '')
        echo "   ⚠ version de Caddy illisible : vérifier qu'elle est ≥ 2.7.5"
        ;;
    *)
        echo "   Caddy $CADDY_VERSION"
        ;;
esac

CADDY_USER=$(systemctl show caddy -p User --value 2>/dev/null || echo caddy)
if [ -d /var/log/caddy ]; then
    for log in agora-access.log agora-api-access.log; do
        [ -f "/var/log/caddy/$log" ] || : > "/var/log/caddy/$log"
        chown "$CADDY_USER:$CADDY_USER" "/var/log/caddy/$log"
        chmod 640 "/var/log/caddy/$log"
    done
    echo "   journaux d'accès prêts pour l'utilisateur $CADDY_USER"
fi

if grep -qF "$IMPORT_LINE" "$CADDYFILE"; then
    echo "   Caddy : import déjà présent, rechargement pour prise en compte"
    caddy validate --config "$CADDYFILE" >/dev/null
    systemctl reload caddy
else
    cp "$CADDYFILE" "$CADDYFILE.bak-$(date +%Y%m%d-%H%M%S)"
    printf '\n# Agora — vhosts autonomes, rafraîchis par la CI dans /opt/agora/caddy/.\n%s\n' "$IMPORT_LINE" >> "$CADDYFILE"
    # Valider AVANT de recharger : un Caddyfile invalide casserait tous les
    # sites de l'hôte, pas seulement Agora.
    caddy validate --config "$CADDYFILE" >/dev/null
    systemctl reload caddy
    echo "   Caddy : import ajouté et rechargé"
fi

if [ -f "$BACKUP_SCRIPT" ]; then
    if grep -qF "$BACKUP_ENTRY" "$BACKUP_SCRIPT"; then
        echo "   sauvegarde : base déjà déclarée"
    else
        sed -i "s|^CONTENEURS=\"\(.*\)\"$|CONTENEURS=\"\1 $BACKUP_ENTRY\"|" "$BACKUP_SCRIPT"
        echo "   sauvegarde : $BACKUP_ENTRY ajouté à CONTENEURS"
    fi
else
    echo "   ⚠ pas de $BACKUP_SCRIPT : la base ne sera PAS sauvegardée (voir docs/deployment.md)"
fi

echo "== Reste à faire à la main (docs/deployment.md)"
if grep -q "CHANGE_ME" "$DEST/.env"; then
    echo "   ⚠ $DEST/.env contient encore des CHANGE_ME (identifiants SMTP Brevo)"
fi
echo "   copier $DEST/.env dans le coffre .agora-secrets/supabase.env ;"
echo "   secret GitHub AGORA_ANON_KEY = ANON_KEY du .env (build de l'app web) ;"
echo "   puis : pousser sur la branche release, ou lancer le workflow Deploy à la main."

#!/bin/sh
# Répète la mise en ligne sur ce poste, puis vérifie la pile de bout en bout.
#
# Monte la pile de PRODUCTION telle quelle (deploy/docker-compose.prod.yml,
# init/zzz-roles.sql, migrate.sh, mêmes images) avec des secrets jetables,
# dans deploy/rehearsal/.work/ (ignoré par git). Seuls diffèrent :
#   - le .env : adresses locales, Mailpit au lieu de Brevo ;
#   - l'override : Mailpit, et un conteneur Caddy à la place de celui de
#     l'hôte, qui sert le vhost de prod transposé en HTTP local (noms d'hôte
#     remplacés par les ports 8480/8481, amonts 127.0.0.1:94xx par les
#     services du réseau compose ; CORS, handle_path et Host de Realtime
#     intacts).
# Puis check.dart parcourt la pile À TRAVERS Caddy : CORS, inscription avec
# le code reçu par e-mail (gabarit lu par URL), REST, Realtime, dépliage
# d'une série par le worker, règle de vie privée, suppression de compte.
#
# À relancer avant tout changement du compose, du vhost, des scripts de
# déploiement ou d'une version d'image. Ne touche pas à la pile locale de
# développement (supabase start) : autres noms, autres ports.
#
#   sh deploy/rehearsal/rehearse.sh           # répète, vérifie, démonte
#   sh deploy/rehearsal/rehearse.sh --keep    # laisse tourner (app sur :8480)
#   sh deploy/rehearsal/rehearse.sh --down    # démonte une répétition gardée
#
# Prérequis : Docker, openssl, et « flutter pub get » fait dans app/ (le
# contrôle réutilise les paquets de l'app).

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
WORK="$HERE/.work"
MODE=${1:-}

teardown() {
    if [ -f "$WORK/docker-compose.yml" ]; then
        (cd "$WORK" && docker compose down -v --remove-orphans >/dev/null 2>&1) || true
    fi
    docker rmi ghcr.io/lelio88/agora-worker:rehearsal >/dev/null 2>&1 || true
    rm -rf "$WORK"
}

if [ "$MODE" = "--down" ]; then
    teardown
    echo "Répétition démontée."
    exit 0
fi

healthy() { [ "$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null)" = healthy ]; }
wait_for() {
    for _ in $(seq 1 60); do
        if "$@"; then return 0; fi
        sleep 2
    done
    echo "ERREUR : délai dépassé ($*)." >&2
    (cd "$WORK" && docker compose logs --tail 40) >&2
    return 1
}

teardown
mkdir -p "$WORK/init" "$WORK/caddy" "$WORK/migrations" "$WORK/email" "$WORK/web"
cp "$ROOT/deploy/docker-compose.prod.yml" "$WORK/docker-compose.yml"
cp "$HERE/docker-compose.override.yml" "$WORK/"
cp "$ROOT/deploy/init/zzz-roles.sql" "$WORK/init/"
cp "$ROOT/deploy/migrate.sh" "$WORK/"
cp "$ROOT"/supabase/migrations/*.sql "$WORK/migrations/"
cp "$ROOT"/supabase/templates/*.html "$WORK/email/"
printf '<!doctype html><title>Agora</title><p>Répétition : déposer ici un flutter build web.\n' \
    > "$WORK/web/index.html"

sh "$ROOT/deploy/gen-secrets.sh" "$ROOT/deploy/production.env.example" | sed \
    -e 's|^SITE_URL=.*|SITE_URL=http://localhost:8480|' \
    -e 's|^API_URL=.*|API_URL=http://localhost:8481|' \
    -e 's|^# EMAIL_TEMPLATES_URL=.*|EMAIL_TEMPLATES_URL=http://caddy:8480/email|' \
    -e 's|^SMTP_USER=.*|SMTP_USER=rehearsal|' \
    -e 's|^SMTP_PASS=.*|SMTP_PASS=rehearsal|' \
    -e 's|^# SMTP_HOST=.*|SMTP_HOST=mailpit|' \
    -e 's|^# SMTP_PORT=.*|SMTP_PORT=1025|' \
    -e 's|^AGORA_TAG=.*|AGORA_TAG=rehearsal|' \
    > "$WORK/.env"

{
    printf '{\n\tauto_https off\n\tadmin off\n}\n\n'
    sed \
        -e 's|^agora\.heianenterprise\.com {|:8480 {|' \
        -e 's|^api\.agora\.heianenterprise\.com {|:8481 {|' \
        -e 's|https://agora\.heianenterprise\.com|http://localhost:8480|g' \
        -e 's|127\.0\.0\.1:9401|auth:9999|' \
        -e 's|127\.0\.0\.1:9402|rest:3000|' \
        -e 's|127\.0\.0\.1:9403|realtime:4000|' \
        "$ROOT/deploy/caddy/agora.caddy"
} > "$WORK/caddy/Caddyfile"

# Configuration d'un « flutter build web » pointé sur la répétition (--keep).
anon=$(sed -n 's/^ANON_KEY=//p' "$WORK/.env")
printf '{"SUPABASE_URL":"http://localhost:8481","SUPABASE_PUBLISHABLE_KEY":"%s","AGORA_WEB_URL":"http://localhost:8480"}\n' \
    "$anon" > "$WORK/web-config.json"

echo "== Image du worker"
docker build -q -t ghcr.io/lelio88/agora-worker:rehearsal "$ROOT/worker" >/dev/null

cd "$WORK"
echo "== Base et GoTrue"
docker compose up -d db auth mailpit caddy >/dev/null 2>&1
wait_for healthy agora_auth
echo "== Migrations"
sh migrate.sh
echo "== PostgREST, Realtime, worker"
docker compose up -d >/dev/null 2>&1
wait_for healthy agora_rest
wait_for healthy agora_realtime
wait_for curl -sf http://127.0.0.1:9404/healthz -o /dev/null
echo "== Second passage des migrations (idempotence)"
sh migrate.sh

echo "== Parcours à travers Caddy"
status=0
dart run --packages="$ROOT/app/.dart_tool/package_config.json" "$HERE/check.dart" "$WORK/.env" \
    </dev/null || status=$?

echo "== Mémoire"
docker stats --no-stream --format '   {{.Name}} {{.MemUsage}}' | grep -E ' ?agora_(db|auth|rest|realtime|worker) ' || true

cd "$ROOT"   # Windows refuse d'effacer le dossier courant
if [ "$MODE" = "--keep" ]; then
    echo "Pile laissée en marche : API http://localhost:8481, Mailpit http://localhost:8482."
    echo "App web : (cd app && flutter build web --dart-define-from-file=$WORK/web-config.json --output=$WORK/web),"
    echo "puis http://localhost:8480. Démonter : sh deploy/rehearsal/rehearse.sh --down"
else
    teardown
fi
exit "$status"

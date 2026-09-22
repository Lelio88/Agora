#!/bin/sh
# Applique le schéma d'Agora (supabase/migrations/) à la base de production.
#
# Lancé par la CI dans /opt/agora, après le démarrage de GoTrue (qui crée
# auth.users, dont le schéma dépend) et avant celui du worker (dont le rôle
# naît dans ces migrations). Idempotent : se relance sans rien rejouer.
#
# Choix non évidents :
#   - suivi dans supabase_migrations.schema_migrations, la table du CLI
#     Supabase : « supabase migration list --db-url » lit le même état ;
#   - chaque migration passe dans UNE transaction avec sa ligne de suivi :
#     une migration qui échoue ne laisse ni demi-schéma ni trace d'avoir
#     été jouée, et le script s'arrête là ;
#   - psql dans le conteneur, en rôle postgres par la socket locale (sans
#     mot de passe), comme le CLI applique les migrations en local ;
#   - le mot de passe du worker passe par l'entrée standard de psql, jamais
#     par sa ligne de commande (visible de tous dans la liste des processus).
#
# Invariant : une migration appliquée n'est jamais modifiée (CLAUDE.md §IV) ;
# ce script ne rejoue pas une version déjà suivie, même si le fichier change.
#
#   sh migrate.sh                       # depuis /opt/agora
#   MIGRATIONS=/chemin sh migrate.sh    # autre dossier de migrations

set -eu

cd "$(dirname "$0")"
MIGRATIONS=${MIGRATIONS:-./migrations}

sql() {
    docker compose exec -T db psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres "$@"
}

WORKER_PASSWORD=$(sed -n 's/^AGORA_WORKER_PASSWORD=//p' .env)
case "$WORKER_PASSWORD" in
    '' | *[!A-Za-z0-9]*)
        echo "ERREUR : AGORA_WORKER_PASSWORD absent de .env, ou pas seulement alphanumérique." >&2
        exit 1
        ;;
esac

sql <<'SQL'
set client_min_messages = warning;
create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (
  version text primary key,
  statements text[],
  name text
);
SQL

applied=$(sql -At -c 'select version from supabase_migrations.schema_migrations')
count=0
for file in "$MIGRATIONS"/*.sql; do
    [ -f "$file" ] || continue
    base=$(basename "$file" .sql)
    version=${base%%_*}
    name=${base#*_}
    if printf '%s\n' "$applied" | grep -qx "$version"; then
        continue
    fi
    echo "   migration $base"
    {
        cat "$file"
        printf "\ninsert into supabase_migrations.schema_migrations (version, name) values ('%s', '%s');\n" \
            "$version" "$name"
    } | sql --single-transaction -f -
    count=$((count + 1))
done
echo "   $count migration(s) appliquée(s)"

printf "alter role agora_worker with login password '%s';\n" "$WORKER_PASSWORD" | sql
# PostgREST relit le schéma (nouvelles tables, fonctions et droits).
sql -c "notify pgrst, 'reload schema';"

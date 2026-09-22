#!/bin/sh
# Remplit les secrets laissés vides d'un gabarit .env et écrit le résultat
# sur la sortie standard. Appelé par bootstrap-server.sh, une seule fois.
#
# Choix non évidents :
#   - ANON_KEY et SERVICE_ROLE_KEY sont des JWT HS256 signés avec
#     JWT_SECRET. Valables 10 ans : ce sont des clés d'API, pas des
#     sessions ; leur révocation passe par un nouveau JWT_SECRET ;
#   - la signature passe par python3 (présent sur Ubuntu), qui lit la clé
#     dans l'environnement. Le repli openssl la reçoit en argument, donc
#     visible un instant dans la liste des processus : sur un serveur
#     partagé, préférer python3 ;
#   - seules les variables VIDES sont remplies : un gabarit déjà rempli
#     ressort inchangé.
#
#   sh gen-secrets.sh production.env.example > .env

set -eu

template=${1:?usage : gen-secrets.sh <gabarit .env>}

hex() { openssl rand -hex "$1"; }
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

JWT_SECRET=$(hex 32)
IAT=$(date +%s)
EXP=$((IAT + 10 * 365 * 24 * 3600))

sign() {
    if command -v python3 >/dev/null 2>&1; then
        JWT_SECRET="$JWT_SECRET" python3 -c 'import base64,hashlib,hmac,os,sys
key = os.environ["JWT_SECRET"].encode()
mac = hmac.new(key, sys.stdin.buffer.read(), hashlib.sha256).digest()
sys.stdout.write(base64.urlsafe_b64encode(mac).decode().rstrip("="))'
    else
        openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | b64url
    fi
}

jwt() {
    header=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)
    payload=$(printf '{"role":"%s","iss":"supabase","iat":%s,"exp":%s}' "$1" "$IAT" "$EXP" | b64url)
    signature=$(printf '%s.%s' "$header" "$payload" | sign)
    printf '%s.%s.%s' "$header" "$payload" "$signature"
}

sed \
    -e "s|^POSTGRES_PASSWORD=$|POSTGRES_PASSWORD=$(hex 24)|" \
    -e "s|^JWT_SECRET=$|JWT_SECRET=$JWT_SECRET|" \
    -e "s|^ANON_KEY=$|ANON_KEY=$(jwt anon)|" \
    -e "s|^SERVICE_ROLE_KEY=$|SERVICE_ROLE_KEY=$(jwt service_role)|" \
    -e "s|^REALTIME_SECRET_KEY_BASE=$|REALTIME_SECRET_KEY_BASE=$(hex 32)|" \
    -e "s|^REALTIME_DB_ENC_KEY=$|REALTIME_DB_ENC_KEY=$(hex 8)|" \
    -e "s|^AGORA_WORKER_PASSWORD=$|AGORA_WORKER_PASSWORD=$(hex 24)|" \
    "$template"

#!/usr/bin/env bash
# gen-env.sh — Generates .env from Vault via the prometheus AppRole (local).
#   Reads secret/postgres-app/dev (Postgres DSN) and secret/redis/dev (Redis
#   password). The DATABASE_URL host is rewritten to postgres-app-db so
#   postgres-exporter reaches the DB over kafka-network.
# Usage: make env
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_DIR="${VAULT_DIR:-$PROJECT_DIR/../vault}"
SECRETS_DIR="$VAULT_DIR/data/secrets"
SECRET_LOCAL_DIR="$PROJECT_DIR/.secrets"
OUT="$PROJECT_DIR/.env"
VAULT_ENV="${VAULT_ENV:-dev}"

VAULT_ADDR="$(grep -m1 '^VAULT_ADDR=' "$VAULT_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '\n\r')"
VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8201}"
export VAULT_SKIP_VERIFY=true

if ! curl -sk -m 5 -o /dev/null "$VAULT_ADDR/v1/sys/health"; then
  echo "ERROR: Vault is not reachable at $VAULT_ADDR. Start it with: cd ../vault && make up && make unseal"
  exit 1
fi

# AppRole auth (role_id/secret_id from repo .secrets/, fallback to vault data/secrets)
ROLE_ID="$(cat "$SECRET_LOCAL_DIR/approle-prometheus-roleid.txt" 2>/dev/null || \
  cat "$SECRETS_DIR/approle-prometheus-roleid.txt" 2>/dev/null || true)"
SECRET_ID="$(cat "$SECRET_LOCAL_DIR/approle-prometheus-secretid.txt" 2>/dev/null || \
  cat "$SECRETS_DIR/approle-prometheus-secretid.txt" 2>/dev/null || true)"
if [ -z "$ROLE_ID" ] || [ -z "$SECRET_ID" ]; then
  echo "ERROR: AppRole credentials missing. Run first: make vault-secrets"
  exit 1
fi

LOGIN_JSON="$(curl -sk -X POST -H "Content-Type: application/json" \
  -d "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" \
  "$VAULT_ADDR/v1/auth/approle/login")"
VAULT_TOKEN="$(echo "$LOGIN_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["auth"]["client_token"])' 2>/dev/null || true)"
if [ -z "$VAULT_TOKEN" ]; then
  echo "ERROR: AppRole login failed. Re-run: make vault-secrets"
  exit 1
fi

read_secret() {
  curl -sk -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/secret/data/$1" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['data']['data']))"
}

echo "=== Reading secrets from Vault (AppRole: prometheus) ==="
PG_JSON="$(read_secret "postgres-app/$VAULT_ENV")"
REDIS_JSON="$(read_secret "redis/$VAULT_ENV")"

DATABASE_URL="$(echo "$PG_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["DATABASE_URL"])')"
REDIS_PASSWORD="$(echo "$REDIS_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["REDIS_PASSWORD"])')"

if [ -z "$DATABASE_URL" ] || [ -z "$REDIS_PASSWORD" ]; then
  echo "ERROR: Incomplete secrets. Run first: make vault-secrets"
  exit 1
fi

# parse DATABASE_URL -> postgresql://user:pass@host:port/db
POSTGRES_USER="$(echo "$DATABASE_URL" | sed -E 's|^.*://([^:]+):.*|\1|')"
POSTGRES_PASSWORD="$(echo "$DATABASE_URL" | sed -E 's|^.*://[^:]+:([^@]+)@.*|\1|')"
POSTGRES_DB="$(echo "$DATABASE_URL" | sed -E 's|^.*/([^/?]+)(\?.*)?$|\1|')"

DATA_SOURCE_NAME="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres-app-db:5432/${POSTGRES_DB}?sslmode=disable"

cat > "$OUT" <<EOF
ENVIRONMENT=${VAULT_ENV:-local}

# Prometheus
PROMETHEUS_PORT=9090

# Exporters (host ports)
POSTGRES_EXPORTER_PORT=9187
REDIS_EXPORTER_PORT=9121
KAFKA_CONNECT_EXPORTER_PORT=9309
KAFKA_EXPORTER_PORT=9308

# Postgres (postgres-exporter DSN, host rewritten to the kafka-network name)
DATA_SOURCE_NAME=${DATA_SOURCE_NAME}

# Redis (redis-exporter, on kafka-network via the container name)
REDIS_ADDR=redis:6379
REDIS_PASSWORD=${REDIS_PASSWORD}
EOF

chmod 0600 "$OUT"
echo ".env generated from Vault ($VAULT_ENV). Source: secret/postgres-app/$VAULT_ENV + secret/redis/$VAULT_ENV (AppRole: prometheus)"

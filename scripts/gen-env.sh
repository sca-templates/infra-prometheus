#!/usr/bin/env bash
# gen-env.sh — Generates .env from Vault (local).
#   Reads secret/api-template/dev (Postgres DSN + Redis password). The
#   DATABASE_URL host is rewritten to postgres-app-db so postgres-exporter
#   reaches the DB over kafka-network.
# Usage: make env
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_DIR="${VAULT_DIR:-$PROJECT_DIR/../vault}"
SECRETS_DIR="$VAULT_DIR/data/secrets"
OUT="$PROJECT_DIR/.env"
VAULT_ENV="${VAULT_ENV:-dev}"

VAULT_ADDR="$(grep -m1 '^VAULT_ADDR=' "$VAULT_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '\n\r')"
VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8201}"
export VAULT_SKIP_VERIFY=true

VAULT_TOKEN="$(cat "$SECRETS_DIR/root-token.txt" 2>/dev/null || \
  docker exec prod-vault-1 cat /vault/data/secrets/root-token.txt 2>/dev/null | tr -d '\n\r' || true)"
if [ -z "$VAULT_TOKEN" ]; then
  echo "ERROR: Could not obtain the Vault token. Is it running? (cd ../vault && make up && make unseal)"
  exit 1
fi

if ! curl -sk -m 5 -o /dev/null "$VAULT_ADDR/v1/sys/health"; then
  echo "ERROR: Vault is not reachable at $VAULT_ADDR. Start it with: cd ../vault && make up && make unseal"
  exit 1
fi

echo "=== Reading secrets from Vault ==="
API_JSON="$(curl -sk -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/secret/data/api-template/$VAULT_ENV" \
  | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin)["data"]["data"]))')"

DATABASE_URL="$(echo "$API_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["DATABASE_URL"])')"
REDIS_PASSWORD="$(echo "$API_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["REDIS_PASSWORD"])')"

if [ -z "$REDIS_PASSWORD" ]; then
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

# Redis (redis-exporter, reached via the host gateway)
REDIS_ADDR=host.docker.internal:6379
REDIS_PASSWORD=${REDIS_PASSWORD}
EOF

chmod 0600 "$OUT"
echo ".env generated from Vault ($VAULT_ENV). Source: secret/api-template/$VAULT_ENV"

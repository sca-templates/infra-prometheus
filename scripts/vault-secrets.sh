#!/usr/bin/env bash
# vault-secrets.sh — Registers the prometheus AppRole in Vault (idempotent).
#   No service-specific secrets: prometheus reads secret/postgres-app/dev and
#   secret/redis/dev (postgres + redis) via gen-env.sh, so the AppRole gets a
#   read-only policy on exactly those two paths.
# Usage: make vault-secrets   (FORCE=1 to recreate the role)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_DIR="${VAULT_DIR:-$PROJECT_DIR/../vault}"
SECRETS_DIR="$VAULT_DIR/data/secrets"
SECRET_LOCAL_DIR="$PROJECT_DIR/.secrets"

VAULT_ADDR="$(grep -m1 '^VAULT_ADDR=' "$VAULT_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '\n\r')"
VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8201}"
VAULT_ENV="${VAULT_ENV:-dev}"
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

echo "=== AppRole 'prometheus' ==="
ROLE_CODE="$(curl -sk -o /dev/null -w '%{http_code}' -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/auth/approle/role/prometheus")"
if [ "$ROLE_CODE" = "404" ]; then
  echo "Registering prometheus service in Vault..."
  if [ -x "$VAULT_DIR/scripts/add-service.sh" ]; then
    bash "$VAULT_DIR/scripts/add-service.sh" prometheus "" \
      --read-policy "secret/data/postgres-app/*,secret/data/redis/*"
  else
    echo "ERROR: $VAULT_DIR/scripts/add-service.sh not found"
    exit 1
  fi
else
  echo "AppRole prometheus already exists. (FORCE=1 to recreate it)"
fi

mkdir -p "$SECRET_LOCAL_DIR"
cp "$SECRETS_DIR/approle-prometheus-roleid.txt" "$SECRET_LOCAL_DIR/approle-prometheus-roleid.txt"
cp "$SECRETS_DIR/approle-prometheus-secretid.txt" "$SECRET_LOCAL_DIR/approle-prometheus-secretid.txt"
chmod 0600 "$SECRET_LOCAL_DIR/approle-prometheus-roleid.txt" "$SECRET_LOCAL_DIR/approle-prometheus-secretid.txt"
echo "AppRole credentials saved to $SECRET_LOCAL_DIR/ (gitignored)"

echo ""
echo "No service-specific secrets required (prometheus reads secret/postgres-app/dev + secret/redis/dev)."
echo "Next step: make env"

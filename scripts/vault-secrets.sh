#!/usr/bin/env bash
# vault-secrets.sh — Registers the prometheus AppRole in Vault (idempotent).
#   No service-specific secrets: prometheus reads secret/api-template/dev
#   (postgres + redis) directly via gen-env.sh.
# Usage: make vault-secrets   (FORCE=1 to recreate the role)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_DIR="${VAULT_DIR:-$PROJECT_DIR/../vault}"
SECRETS_DIR="$VAULT_DIR/data/secrets"

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
if echo "$(curl -sk -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/auth/approle/role/prometheus")" | grep -q 'does not exist'; then
  echo "Registering prometheus service in Vault..."
  if [ -x "$VAULT_DIR/scripts/add-service.sh" ]; then
    bash "$VAULT_DIR/scripts/add-service.sh" prometheus kv-reader
  else
    echo "ERROR: $VAULT_DIR/scripts/add-service.sh not found"
    exit 1
  fi
else
  echo "AppRole prometheus already exists. (FORCE=1 to recreate it)"
fi

echo ""
echo "No service-specific secrets required (prometheus reads secret/api-template/dev)."
echo "Next step: make env"

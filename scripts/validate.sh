#!/usr/bin/env bash
# validate.sh — Static + runtime validation of the Prometheus stack.
#   Mirrors .github/workflows/validate.yml plus live checks (health, up{}).
#   Strict jobs must scrape; vault, kong and kafka-connect are tolerated down
#   (vault needs telemetry.prometheus_retention_time in the vault/ config).
# Usage: make validate
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

PROM_IMAGE="prom/prometheus:v2.53.0"
PROM_URL="http://127.0.0.1:9090"
STRICT_JOBS=(prometheus consul postgres-exporter redis-exporter)
TOLERATED_JOBS=(vault kong kafka-connect)

FAIL=0

section() { echo; echo "=== $1 ==="; }
ok() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1"; FAIL=1; }

section "1. Shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh && ok 'scripts/*.sh'
else
  echo "  [SKIP] shellcheck not installed"
fi

section "2. Docker Compose config"
docker compose -f compose.yml -p prometheus config --quiet
ok 'compose.yml is valid'

section "3. promtool check config"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
: > "$TMP_DIR/vault-token"
docker run --rm --entrypoint promtool \
  -v "$PROJECT_DIR/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  -v "$TMP_DIR/vault-token:/etc/prometheus/vault-token:ro" \
  "$PROM_IMAGE" check config /etc/prometheus/prometheus.yml
ok 'prometheus.yml is valid'

section "4. Prometheus health"
if curl -sf "$PROM_URL/-/healthy" >/dev/null 2>&1; then
  ok 'GET /-/healthy'
else
  fail 'prometheus not reachable (run: make up)'
fi

section "5. up{} sanity"
query_up() {
  curl -sf --max-time 5 -G "$PROM_URL/api/v1/query" --data-urlencode "query=count(up{job=\"$1\"} == 1)" \
    | python3 -c 'import sys,json; r=json.load(sys.stdin)["data"]["result"]; print(r[0]["value"][1] if r else "none")' \
    2>/dev/null || echo none
}

for job in "${STRICT_JOBS[@]}"; do
  value="$(query_up "$job")"
  if [ "$value" != "0" ] && [ "$value" != "none" ]; then
    ok "up{job=\"$job\"} == 1"
  else
    fail "up{job=\"$job\"} == $value (expected 1)"
  fi
done

for job in "${TOLERATED_JOBS[@]}"; do
  value="$(query_up "$job")"
  if [ "$value" = "1" ]; then
    ok "up{job=\"$job\"} == 1"
  else
    echo "  [WARN] up{job=\"$job\"} == $value (tolerated down)"
  fi
done

if [ "$FAIL" -eq 0 ]; then
  echo
  echo '=== ALL CHECKS PASSED ==='
else
  echo
  echo '=== SOME CHECKS FAILED ==='
  exit 1
fi

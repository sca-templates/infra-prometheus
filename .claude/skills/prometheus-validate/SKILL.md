---
name: prometheus-validate
description: Validate the Prometheus stack configs and docs. Use when the user asks to run or fix `make validate`, promtool, shellcheck, docker compose config, or reports a failing CI job from .github/workflows/validate.yml.
---

# Validate the stack

`make validate` runs the same checks as the CI pipeline
(`.github/workflows/validate.yml`): shellcheck, compose config, promtool,
`/-/healthy` and an `up{}` sanity query.

## Steps

1. Run `make validate` from the repo root.
2. If it fails, isolate the problem with the individual checks:
   - shellcheck: `shellcheck scripts/*.sh`
   - compose: `cp .env.example .env && docker compose -f compose.yml config --quiet`
   - promtool: `docker exec prometheus promtool check config /etc/prometheus/prometheus.yml`
   - health: `curl <http://127.0.0.1:9090/-/healthy>`
   - sanity: `curl '<http://127.0.0.1:9090/api/v1/query?query=up>'`
3. Common fixes:
   - Missing env interpolation: use `${VAR:-default}` defaults in compose so
     `docker compose config` passes without `.env`.
   - YAML indent errors: keep 2-space indentation; `promtool check config`
     only validates `prometheus.yml`, not `kafka-connect-jmx.yml`.
   - Vault token missing: `/etc/prometheus/vault-token` is mounted from
     `../vault/data/secrets/root-token.txt`; re-run `make up` after Vault is
     re-initialized.
4. Run `make validate` again and confirm exit 0.

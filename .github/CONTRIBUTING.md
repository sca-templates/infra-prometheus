# Contributing to sca-prometheus

> Prometheus observability for the local stack — central TSDB (30-day retention) scraping Vault, Consul, Postgres, Redis, Kafka Connect (Debezium CDC) and NestJS microservices, with bundled postgres, redis and JMX exporters feeding the Grafana dashboards. Docs-as-code: all changes land through a PR with review.

## Ground rules

- **English only** — notes, commits, and PR descriptions are written in English.
- **No secrets in the repo** — `.env` is gitignored and generated from Vault; never commit tokens, role IDs or passwords. New configuration with secrets goes through `scripts/vault-secrets.sh` and `scripts/gen-env.sh`.
- **Docs-as-code** — every change goes through a pull request and is reviewed.

## Repository layout

```text
compose.yml              Services: prometheus, postgres-exporter, redis-exporter, jmx-exporter
prometheus.yml           Scrape configs (TSDB, retention, targets, labels)
kafka-connect-jmx.yml    JMX exporter rules for Kafka Connect (Debezium CDC)
Makefile                 help | setup | all | up | down | stop | restart | logs | ps | validate | clean | env
scripts/                 vault-secrets.sh | gen-env.sh | validate.sh
.env.example             Non-secret defaults, ports and ENVIRONMENT
.github/                 CI, PR template, dependabot, markdown link-check config
```

## Adding or changing a scrape target

1. Configure the exporter or service metrics endpoint (e.g. the JMX rules in `kafka-connect-jmx.yml`).
2. Add or edit the scrape job in `prometheus.yml` (job, metrics_path, port, labels).
3. Register the target in `consul/scripts/register-services.sh` (TCP check on `127.0.0.1:<port>`) so it is visible in Consul.
4. If the service binds a new host port, add it to `.env.example` and the compose file.
5. Update the README tables (ports, jobs, services monitored).

## Contribution flow

1. Branch off `main`: `git checkout -b feat/<topic>`.
2. Create or edit the files following the conventions above.
3. Run the checks (see Tooling).
4. Open a PR and fill the checklist from the template.

## Definition of done

- [ ] Content is in English.
- [ ] `.env.example` is updated when new variables are added.
- [ ] No secrets or tokens are committed.
- [ ] `make validate` passes locally.
- [ ] `promtool check config prometheus.yml` passes.
- [ ] `docker compose -f compose.yml config --quiet` passes.
- [ ] `shellcheck scripts/*.sh` passes.
- [ ] `markdownlint` and link check pass (CI runs them too).
- [ ] `README.md` is updated when the stack, ports or commands change.

## Tooling

```sh
# Validate the whole stack (shellcheck, compose, promtool)
make validate

# Lint markdown
npx --yes markdownlint-cli2 README.md AGENTS.md CLAUDE.md .github/PULL_REQUEST_TEMPLATE.md .github/CONTRIBUTING.md docs/handbook/README.md .claude/skills/**/SKILL.md .opencode/command/*.md

# Check links in a single file (config lives in .github/)
npx --yes markdown-link-check -c .github/markdown-link-check.json <file>
```

## License

This repository is licensed under the MIT License (see [LICENSE](../LICENSE)).

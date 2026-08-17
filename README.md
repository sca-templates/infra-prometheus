# prometheus — Prometheus + bundled exporters

Central Prometheus TSDB (30-day retention) for the local `aws/` monorepo,
scraping **Vault**, **Consul**, **Postgres**, **Redis** and **Kafka Connect
(Debezium CDC)**, with bundled postgres-exporter, redis-exporter and a JMX
exporter for Kafka Connect. UI and API on `http://127.0.0.1:9090` (**loopback
only**). Production reference (same image versions):
`../ansible/roles/observability/`.

| Container              | Image                                           | Host port        |
| ---------------------- | ----------------------------------------------- | ---------------- |
| prometheus             | `prom/prometheus:v2.53.0`                       | `127.0.0.1:9090` |
| postgres-exporter      | `prometheuscommunity/postgres-exporter:v0.15.0` | `127.0.0.1:9187` |
| redis-exporter         | `oliver006/redis_exporter:v1.62.0`              | `127.0.0.1:9121` |
| kafka-connect-exporter | `bitnamilegacy/jmx-exporter:0.20.0`             | `127.0.0.1:9309` |

Integrates with the sibling projects:

- **Vault** (`../vault`) — source of `.env` secrets and the scrape token.
- **Consul** (`../consul`) — scraped at `127.0.0.1:8500`; registers the stack
  services with TCP checks (pending).
- **postgres-app** (`../postgres-app`) — source DB for postgres-exporter
  (`postgres-app-db:5432`).
- **Redis** (`../redis`) — scraped via redis-exporter (`host.docker.internal:6379`).
- **Kafka Connect** (`../kafka`) — JMX scraped at `127.0.0.1:9309` (needs
  `JMXPORT=8778` on `kafka-connect`).

## Quick Start (local)

```bash
# 1. Vault running and unsealed (once)
cd ../vault && make dev

# 2. All-in-one: Vault secrets + .env + up
cd ../prometheus && make all

# 3. Verify
make validate
```

On subsequent starts `make up` is enough.

## Commands

| Command                                                              | Description                                                                                |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `make setup`                                                         | First time: Vault AppRole + `.env` from Vault (idempotent)                                 |
| `make all`                                                           | `setup` + `up`                                                                             |
| `make up`                                                            | Starts the stack and waits for Prometheus to become healthy (`../scripts/wait-healthy.sh`) |
| `make validate`                                                      | shellcheck + compose config + promtool + `/-/healthy` + `up{}` sanity query                |
| `make vault-secrets`                                                 | Registers the `prometheus` AppRole in Vault                                                |
| `make env`                                                           | Generates `.env` from Vault                                                                |
| `make down` / `make restart` / `make stop` / `make logs` / `make ps` | Stack management                                                                           |
| `make clean`                                                         | `down -v` + removes `.env`                                                                 |

## Scrape targets

| Job               | Target           | Notes                                 |
| ----------------- | ---------------- | ------------------------------------- |
| prometheus        | `localhost:9090` | self-scrape                           |
| vault             | `127.0.0.1:8201` | `https`, bearer token                 |
| consul            | `127.0.0.1:8500` | `/v1/agent/metrics?format=prometheus` |
| kong              | `kong:8001`      | tolerated down until `kong/` exists   |
| postgres-exporter | `127.0.0.1:9187` | `pg_*` metrics                        |
| redis-exporter    | `127.0.0.1:9121` | `redis_*` metrics                     |
| kafka-connect     | `127.0.0.1:9309` | JMX rules in `kafka-connect-jmx.yml`  |

Commented until a real target exists: broker kafka-exporter (`127.0.0.1:9308`)
and microservice jobs (`127.0.0.1:9101`–`9104`). Full details in
[docs/data-sources.md](docs/data-sources.md).

## How the secrets flow works (local)

1. `scripts/vault-secrets.sh` registers the `prometheus` AppRole in Vault.
2. `scripts/gen-env.sh` (`make env`) reads `secret/postgres-app/dev` +
   `secret/redis/dev` and generates `.env` (gitignored, `chmod 600`) with
   `DATA_SOURCE_NAME` (Postgres DSN rewritten to `postgres-app-db:5432`),
   `REDIS_ADDR` and `REDIS_PASSWORD`.
3. Prometheus mounts the Vault root token read-only from
   `../vault/data/secrets/root-token.txt` → `/etc/prometheus/vault-token` and
   uses it as bearer token for the Vault scrape.

After a Vault re-init (`make clean` in `../vault`) the token changes: re-run
`make up` to remount it.

## Networking

- **Prometheus runs on the host network** (`network_mode: host`) and binds its
  UI/API to loopback only (`--web.listen-address=127.0.0.1:9090`). This is
  required because the host firewall (UFW, default deny) drops TCP from Docker
  bridges to host-network services — Consul (`network_mode: host`) would
  otherwise be unreachable. Every scrape target is therefore a published
  `127.0.0.1:<port>`.
- The **exporters** join the external **`kafka-network`** (name resolution):
  postgres-exporter → `postgres-app-db:5432`, kafka-connect-exporter →
  `kafka-connect:8778`.
- **Redis** is not on `kafka-network`; redis-exporter reaches it via
  `host.docker.internal` (`extra_hosts: host-gateway`).
- All published ports bind to **loopback only**; nothing is exposed on the LAN.

## Troubleshooting

| Symptom                                     | Probable cause                             | Fix                                                               |
| ------------------------------------------- | ------------------------------------------ | ----------------------------------------------------------------- |
| `up{job="kong"} == 0` (`no such host`)      | `kong/` stack doesn't exist yet            | Expected; tolerated down                                          |
| `up{job="consul"} == 0` (timeout)           | UFW drops container→host traffic           | Prometheus is on host network for this reason; check `make ps`    |
| `up{job="kafka-connect"} == 0`              | JMX not enabled on `kafka-connect`         | Set `JMXPORT=8778` in `kafka/docker-compose.yml`                  |
| Token file unreadable / `permission denied` | Prometheus container ran as `nobody`       | Compose pins `user: "0:0"`; re-run `make up`                      |
| `make env` can't find the token             | Vault is not running/unsealed              | `cd ../vault && make dev`                                         |
| Stale duplicate series for a job            | Old instance labels from a previous config | They expire after 5 min; `validate.sh` uses `count(up{job=…}==1)` |

## Structure

```text
├── compose.yml                  # prometheus (host net) + 3 exporters
├── prometheus.yml               # scrape configs
├── kafka-connect-jmx.yml        # JMX rules for Kafka Connect
├── Makefile                     # orchestrator
├── .env.example                 # non-secret vars and ports
├── scripts/                     # vault-secrets, gen-env, validate
├── docs/                        # architecture, data sources
└── .claude/skills/ + .opencode/ # agent skills and commands
```

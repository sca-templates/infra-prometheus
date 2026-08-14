# Prometheus — Data Sources

> Every scrape job Prometheus runs against the local stack, and the metric namespaces each source contributes.

## Global config

| Setting | Value |
|---|---|
| `scrape_interval` | 15s |
| `evaluation_interval` | 15s |
| `external_labels` | `project=sca`, `environment=dev` |

## Scrape jobs

| Job | Target | `metrics_path` / params | Notes |
|---|---|---|---|
| prometheus | `localhost:9090` | default `/metrics` | self-scrape |
| vault | `host.docker.internal:8201` | `/v1/sys/metrics`, `params.format=prometheus`, `scheme: https`, `tls_config.insecure_skip_verify` | `bearer_token_file: /etc/prometheus/vault-token` |
| consul | `host.docker.internal:8500` | `/v1/agent/metrics`, `params.format=prometheus` | |
| kong | `kong:8001` | `/metrics` | tolerated down until `kong/` exists |
| postgres-exporter | `postgres-exporter:9187` | default `/metrics` | `pg_*` metrics |
| redis-exporter | `redis-exporter:9121` | default `/metrics` | `redis_*` metrics |
| kafka-connect | `kafka-connect-exporter:9309` | default `/metrics` | JMX rules in `kafka-connect-jmx.yml` |
| kafka | `kafka-exporter:9308` | default `/metrics` | **commented** — best-effort broker |
| ms-auth | `host.docker.internal:9101` | `/metrics` | **commented** until the service exists |
| ms-notifications | `host.docker.internal:9102` | `/metrics` | **commented** until the service exists |
| ms-logging | `host.docker.internal:9103` | `/metrics` | **commented** until the service exists |
| ms-ai | `host.docker.internal:9104` | `/metrics` | **commented** until the service exists |

## Metric namespaces

| Prefix | Source |
|---|---|
| `up`, `scrape_duration_seconds`, `scrape_samples_scraped` | Prometheus, per-target |
| `prometheus_tsdb_*`, `prometheus_engine_*` | Prometheus self-scrape |
| `vault_*` | Vault `/v1/sys/metrics` |
| `consul_*` | Consul `/v1/agent/metrics` |
| `pg_*` | postgres-exporter |
| `redis_*` | redis-exporter |
| `kafka_connect_*`, `debezium_*` | JMX exporter for Kafka Connect |

## Commented jobs policy

Jobs stay **commented** until a real target exists, never active against nothing:

- **kafka** (broker) — `apache/kafka:3.7.1` ignores `KAFKA_JMX_PORT`, so the exporter would have no endpoint; enable only when the broker honours JMX.
- **ms-*** (microservices) — each NestJS service exposes `/metrics` on a dedicated port (9101–9104) when it exists; uncomment the job then.

## Related

- [architecture.md](architecture.md) — component topology and networking.
- [README.md](../README.md) — commands, stack lifecycle and troubleshooting.

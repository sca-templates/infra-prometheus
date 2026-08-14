---
name: promql
description: Write and debug PromQL queries against the local Prometheus API. Use when the user asks for a PromQL expression, a metric name for up{}, or wants to query /api/v1/query or /api/v1/query_range.
---

# PromQL

Prometheus UI: <http://127.0.0.1:9090> (loopback only).

## API

- Instant: `curl '<http://127.0.0.1:9090/api/v1/query?query=up>'`
- Range: `curl '<http://127.0.0.1:9090/api/v1/query_range?query=up&start=...&end=...&step=15s>'`

## Metric cheat sheet

- `up`, `scrape_duration_seconds`, `scrape_samples_scraped`
- `vault_*` (Vault `/v1/sys/metrics`), `consul_*` (Consul `/v1/agent/metrics`)
- `pg_*` (postgres-exporter), `redis_*` (redis-exporter)
- `kafka_connect_*` / `debezium_*` (JMX exporter for Kafka Connect)
- Prometheus self: `prometheus_tsdb_*`, `prometheus_engine_*`

## Common patterns

- Jobs with a down target: `count(up == 0)`
- Error rate: `sum(rate(<metric>_total[5m])) by (job)`
- Latency p95: `histogram_quantile(0.95, sum(rate(<metric>_bucket[5m])) by (le))`

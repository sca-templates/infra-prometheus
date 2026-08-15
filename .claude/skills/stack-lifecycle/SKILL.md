---
name: stack-lifecycle
description: Start, stop and troubleshoot the Prometheus stack. Use when the user asks to make up/down/stop/restart, check health or targets, or fix a target that is not up or a Vault token mount issue.
---

# Stack lifecycle

- `make up` / `make all` — compose up + `wait-healthy.sh prometheus`
- `make down` — stop and remove containers
- `make stop` / `make restart` — stop without removing / down + up
- `make ps` — container status
- `make logs` — follow logs
- `make clean` — `down -v` + remove `.env` and volumes (asks confirmation)

## Health checks

- `curl <http://127.0.0.1:9090/-/healthy>`
- `curl '<http://127.0.0.1:9090/api/v1/targets>'` — targets up except kong
  (until `kong/` exists) and possibly kafka-connect (until `JMXPORT=8778` is
  set on `kafka-connect`) — both tolerated in `validate.sh`

## Troubleshooting

- Target not up: check the exporter container logs and that the port is bound
  on `127.0.0.1` (prometheus runs on the host network, exporters publish on
  loopback).
- Vault token: `/etc/prometheus/vault-token` is mounted from
  `../vault/data/secrets/root-token.txt`; after Vault re-init (`make clean`),
  re-run `make up` to remount it.
- Kafka Connect JMX: requires `JMXPORT=8778` on `kafka-connect` in
  `kafka/docker-compose.yml`.
- redis is NOT on `kafka-network`: redis-exporter reaches it via
  `host.docker.internal` (`extra_hosts: host-gateway`).

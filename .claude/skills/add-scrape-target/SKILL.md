---
name: add-scrape-target
description: Add or change a Prometheus scrape target. Use when the user asks to monitor a new service or exporter, edit prometheus.yml scrape_configs, add JMX rules to kafka-connect-jmx.yml, or register a service in Consul.
---

# Add a scrape target

Follow the conventions in AGENTS.md. Microservice jobs (9101-9104) stay
commented until a real target exists.

## Steps

1. Configure the exporter or the service metrics endpoint (e.g. the JMX rules
   in `kafka-connect-jmx.yml` for Kafka Connect).
2. Add or edit the job in `prometheus.yml`: `job_name`, `metrics_path`,
   target and labels.
3. Register the service in Consul: add `name:port` to `SERVICES` in
   `../consul/scripts/register-services.sh` and the name to `EXPECTED` in
   `../consul/scripts/validate.sh` (TCP checks on `127.0.0.1:<port>`).
4. If a new host port appears, add it to `.env.example` and the compose file.
5. Update the README tables (ports, jobs, monitored services).
6. Run `make validate` and open a PR with the checklist from the template.

# prometheus-template

Prometheus observability for the local stack — central TSDB (30-day retention) scraping Vault, Consul, Postgres, Redis, Kafka Connect (Debezium CDC) and NestJS microservices (/metrics, 9101–9104). Bundled postgres, redis and JMX exporters with PromQL-ready up{} jobs feeding the Grafana dashboards; UI on 127.0.0.1:9090.

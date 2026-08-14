---
description: Run the full Prometheus validation suite (shellcheck, compose, promtool, health, up{} query).
agent: build
---

# Validate

Run `make validate` from the repo root and report the result. If a check
fails, isolate it with the individual commands in the `prometheus-validate`
skill and fix it, then re-run `make validate`.

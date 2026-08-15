SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

COMPOSE_FILE := compose.yml
COMPOSE_PROJECT_NAME := prometheus
COMPOSE := docker compose -f $(COMPOSE_FILE) -p $(COMPOSE_PROJECT_NAME)
VAULT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))/../vault

.PHONY: help
help:
	@echo 'prometheus — Prometheus + bundled exporters'
	@echo ''
	@echo '  make setup         First time: Vault secrets + .env (idempotent)'
	@echo '  make all           setup + up (all-in-one)'
	@echo '  make up            Start the stack and wait for /-/healthy'
	@echo '  make validate      shellcheck + compose config + promtool + health + up{} sanity'
	@echo ''
	@echo '  make vault-secrets Register the prometheus AppRole in Vault'
	@echo '  make env           Generate .env from Vault'
	@echo ''
	@echo '  make down          Stop and remove stack'
	@echo '  make restart       down + up'
	@echo '  make stop          Stop without removing'
	@echo '  make logs          Live logs'
	@echo '  make ps            Container status'
	@echo '  make clean         down + remove .env and volume'

.PHONY: vault-secrets
vault-secrets:
	@echo '=== Registering prometheus AppRole in Vault ==='
	scripts/vault-secrets.sh

.PHONY: env
env:
	@echo '=== Generating .env from Vault ==='
	scripts/gen-env.sh

.PHONY: setup
setup: vault-secrets env
	@echo '=== Setup complete. Next: make up ==='

.PHONY: up
up:
	@echo '=== Starting Prometheus stack ==='
	$(COMPOSE) up -d
	../scripts/wait-healthy.sh prometheus

.PHONY: validate
validate:
	@echo '=== Validating Prometheus stack ==='
	scripts/validate.sh

.PHONY: all
all: setup up
	@echo ''
	@echo '============================================'
	@echo '  Prometheus ready:'
	@echo '  UI + API : http://127.0.0.1:9090'
	@echo '============================================'

.PHONY: down
down:
	@echo '=== Stopping stack ==='
	$(COMPOSE) down

.PHONY: restart
restart: down up

.PHONY: stop
stop:
	$(COMPOSE) stop

.PHONY: logs
logs:
	$(COMPOSE) logs -f

.PHONY: ps
ps:
	$(COMPOSE) ps

.PHONY: clean
clean:
	@echo '=== Cleaning up ==='
	-$(COMPOSE) down -v 2>/dev/null || true
	rm -f .env
	@echo 'Done.'

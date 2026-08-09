#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

docker compose -f "$COMPOSE_FILE" up -d \
  firecrawl-rabbitmq \
  firecrawl-nuq-postgres \
  firecrawl-playwright \
  firecrawl

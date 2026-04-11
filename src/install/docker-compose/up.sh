#!/usr/bin/env bash
# Ensure the ADK .env exists, then bring docker compose services up.
# Postgres, Ollama, and Obsidian MCP are all managed here.
# Idempotent: --no-recreate means already-running containers are left alone.
#
# Required env vars:
#   POSTGRES_PASSWORD  — written into .env if not already present
#   OBSIDIAN_API_KEY   — written into .env if not already present
#   INSTALL_PATH       — path to src/install/ (used to resolve project root)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECT_ROOT="$(cd "${INSTALL_PATH}/../.." && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${OBSIDIAN_API_KEY:?OBSIDIAN_API_KEY is required}"

header "Docker Compose Services (Postgres · Ollama · Obsidian MCP)"

ENV_FILE="${PROJECT_ROOT}/.env"

# Write .env if missing or credentials changed
cat > "${ENV_FILE}" <<ENV
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
OBSIDIAN_API_KEY=${OBSIDIAN_API_KEY}
ENV

step "Bringing up compose services..."
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" --env-file "${ENV_FILE}" \
  up -d --no-recreate --pull missing

# Wait for Postgres to be healthy
if ! docker exec ogham-postgres pg_isready -U ogham &>/dev/null 2>&1; then
  info "Waiting for Postgres to be healthy..."
  tries=0
  until docker exec ogham-postgres pg_isready -U ogham &>/dev/null 2>&1; do
    sleep 2; tries=$((tries+1))
    [[ $tries -gt 30 ]] && error "Postgres not ready. Run: docker logs ogham-postgres"
  done
fi
log "Postgres is healthy"

# Pull nomic-embed-text into the ollama container (idempotent)
if ! docker exec adk-ollama ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
  step "Pulling nomic-embed-text into Ollama container..."
  docker exec adk-ollama ollama pull nomic-embed-text
  log "Embedding model ready"
else
  skip "nomic-embed-text (already in Ollama container)"
fi

log "All compose services are up"

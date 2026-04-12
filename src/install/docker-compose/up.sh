#!/usr/bin/env bash
# Write .env from saved credentials and bring docker compose services up.
# Idempotent: --no-recreate leaves already-running containers alone.
#
# Credentials are loaded from STATE_DIR/setup-inputs (written by run.sh).
# POSTGRES_PASSWORD and OBSIDIAN_API_KEY can also be passed as env vars.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECT_ROOT="$(cd "${INSTALL_PATH}/../.." && pwd)"
STATE_DIR="${STATE_DIR:-$HOME/.config/ogham}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# Load saved credentials if not already exported
if [[ -z "${POSTGRES_PASSWORD:-}" || -z "${OBSIDIAN_API_KEY:-}" ]]; then
  if [[ -f "${STATE_DIR}/setup-inputs" ]]; then
    # shellcheck disable=SC1091
    source "${STATE_DIR}/setup-inputs"
    POSTGRES_PASSWORD="${SAVED_POSTGRES_PASSWORD:-ogham}"
    OBSIDIAN_API_KEY="${SAVED_OBSIDIAN_KEY:-REPLACE_WITH_OBSIDIAN_API_KEY}"
    export POSTGRES_PASSWORD OBSIDIAN_API_KEY
  fi
fi

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${OBSIDIAN_API_KEY:?OBSIDIAN_API_KEY is required}"

header "Docker Compose Services (Postgres · Ollama · Obsidian MCP)"

ENV_FILE="${PROJECT_ROOT}/.env"

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
log "All compose services are up"

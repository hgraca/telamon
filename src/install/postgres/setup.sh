#!/usr/bin/env bash
# Deploy docker-compose.yml + .env to STATE_DIR and bring containers up.
# Uses docker-compose.yml at the project root as the source of truth — no compose content here.
#
# Required env vars (set by run.sh after collect_inputs):
#   PG_PASSWORD        — Postgres password
#   OBSIDIAN_API_KEY   — Obsidian Local REST API key
#   STATE_DIR          — directory for state files (default: ~/.config/ogham)
#   INSTALL_PATH       — path to src/install/ (used to locate project root)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECT_ROOT="$(cd "${INSTALL_PATH}/../.." && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

: "${PG_PASSWORD:?PG_PASSWORD is required}"
: "${OBSIDIAN_API_KEY:?OBSIDIAN_API_KEY is required}"
STATE_DIR="${STATE_DIR:-$HOME/.config/ogham}"

header "Postgres + pgvector (Docker)"

mkdir -p "${STATE_DIR}/pgdata"

# Copy compose file into state dir (idempotent — always refresh so image/tag changes land)
cp "${PROJECT_ROOT}/docker-compose.yml" "${STATE_DIR}/docker-compose.yml"

# Write .env with real credentials
cat > "${STATE_DIR}/.env" <<ENV
POSTGRES_PASSWORD=${PG_PASSWORD}
OBSIDIAN_API_KEY=${OBSIDIAN_API_KEY}
ENV

# Pull images only if not cached
if ! docker image inspect pgvector/pgvector:pg17 &>/dev/null; then
  step "Pulling pgvector/pgvector:pg17..."
  docker pull pgvector/pgvector:pg17
else
  skip "pgvector image"
fi

if ! docker image inspect oleksandrkucherenko/obsidian-mcp:latest &>/dev/null; then
  step "Pulling obsidian-mcp image..."
  docker pull oleksandrkucherenko/obsidian-mcp:latest
else
  skip "obsidian-mcp image"
fi

postgres_running=false
obsidian_running=false
docker ps 2>/dev/null | grep -q "ogham-postgres" && postgres_running=true
docker ps 2>/dev/null | grep -q "obsidian-mcp"   && obsidian_running=true

if $postgres_running && $obsidian_running; then
  skip "Containers (both running)"
  docker compose -f "${STATE_DIR}/docker-compose.yml" up -d --no-recreate &>/dev/null || true
else
  step "Starting containers..."
  docker compose -f "${STATE_DIR}/docker-compose.yml" up -d
  log "Containers started"
fi

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

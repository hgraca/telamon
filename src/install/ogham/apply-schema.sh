#!/usr/bin/env bash
# Download and apply the Ogham database schema into the running Postgres container.
# Idempotent: skipped if state flag 'schema_applied' is set.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Ogham Database Schema"

if state.done "schema_applied"; then
  skip "Schema (already applied)"; exit 0
fi

step "Downloading schema..."
curl -fsSL \
  "https://raw.githubusercontent.com/ogham-mcp/ogham-mcp/main/sql/schema_postgres.sql" \
  -o /tmp/ogham-schema.sql

step "Applying schema..."
docker exec -i ogham-postgres psql -U ogham -d ogham < /tmp/ogham-schema.sql

state.mark "schema_applied"
log "Schema applied"

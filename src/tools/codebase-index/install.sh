#!/usr/bin/env bash
# Register the opencode-codebase-index MCP server in storage/opencode.jsonc.
# The server runs via npx — no binary installation required.
# Also ensures the required Ollama embedding model (nomic-embed-text) is pulled.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "codebase-index MCP"

# ── Ensure nomic-embed-text model is available in Ollama ──────────────────────
# codebase-index uses nomic-embed-text for vector embeddings via the Ollama
# container at 127.0.0.1:17434. The ollama-init container also pulls this model
# at docker compose up, but if the container was restarted or update installed
# codebase-index fresh, the model may be missing.
if docker exec telamon-ollama ollama list 2>/dev/null | grep -q "nomic-embed-text"; then
  skip "nomic-embed-text model (already in Ollama)"
else
  step "Pulling nomic-embed-text model into Ollama..."
  if docker exec telamon-ollama ollama pull nomic-embed-text 2>/dev/null; then
    log "nomic-embed-text model pulled"
  else
    warn "Could not pull nomic-embed-text — Ollama container may not be running yet"
    info "The model will be pulled automatically when the ollama-init container starts"
  fi
fi

# ── Register MCP server ──────────────────────────────────────────────────────
opencode.upsert_mcp "codebase-index" '{
  "type": "local",
  "command": ["npx", "-y", "-p", "opencode-codebase-index", "-p", "@modelcontextprotocol/sdk", "opencode-codebase-index-mcp", "--project", "."],
  "enabled": true
}'

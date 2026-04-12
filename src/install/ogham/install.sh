#!/usr/bin/env bash
# Install ogham-mcp via uv (with postgres + rerank extras), write its global
# config env file, activate the profile, and register its MCP block in
# opencode.jsonc.
#
# ogham v0.9+ reads settings from env vars / ~/.ogham/config.env (pydantic-settings).
# It does NOT read ~/.config/ogham/config.toml.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SECRETS_DIR="${SECRETS_DIR:-$(cd "${INSTALL_PATH}/../.." && pwd)/storage/secrets}"
export SECRETS_DIR
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Ogham MCP"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Install binary (with postgres driver + rerank extras) ─────────────────────
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${OGHAM_PROFILE:?OGHAM_PROFILE is required}"

if ! command -v ogham &>/dev/null; then
  step "Installing ogham-mcp[postgres,rerank] via uv..."
  uv tool install "ogham-mcp[postgres,rerank]"
  export PATH="$HOME/.local/bin:$PATH"
  log "Ogham installed"
else
  # Ensure postgres + rerank extras are present even on re-runs
  step "Ensuring ogham-mcp[postgres,rerank] extras are installed..."
  uv tool upgrade ogham-mcp --extra postgres --extra rerank 2>/dev/null \
    || uv tool install "ogham-mcp[postgres,rerank]" 2>/dev/null \
    || warn "Could not upgrade ogham extras — try: uv tool install 'ogham-mcp[postgres,rerank]'"
  log "Ogham extras verified (installed)"
fi

# ── Write global config env (~/.ogham/config.env) ─────────────────────────────
# ogham uses pydantic-settings: reads ~/.ogham/config.env as global fallback.
# Field names are uppercased: database_backend → DATABASE_BACKEND, etc.
OGHAM_CONFIG_DIR="$HOME/.ogham"
mkdir -p "${OGHAM_CONFIG_DIR}"

sed \
  -e "s/{{POSTGRES_PASSWORD}}/${POSTGRES_PASSWORD}/g" \
  -e "s/{{OGHAM_PROFILE}}/${OGHAM_PROFILE}/g" \
  "${SCRIPT_DIR}/config.tmpl.env" > "${OGHAM_CONFIG_DIR}/config.env"
log "Ogham config written → ${OGHAM_CONFIG_DIR}/config.env"

# ── Health check ───────────────────────────────────────────────────────────────
if ogham health &>/dev/null 2>&1; then
  log "Ogham ↔ Postgres: connected"
else
  warn "Ogham health check failed — Postgres may still be warming up. Run 'ogham health' to verify."
fi

# ── Activate profile ───────────────────────────────────────────────────────────
step "Activating profile: ${OGHAM_PROFILE}"
ogham use "${OGHAM_PROFILE}" 2>/dev/null || true
log "Profile: ${OGHAM_PROFILE}"

# ── Write database URL secret ─────────────────────────────────────────────────
secrets.write "ogham-database-url" "postgresql://ogham:${POSTGRES_PASSWORD}@localhost:5432/ogham"

# ── Register MCP server in opencode.jsonc ─────────────────────────────────────
# Env var names must match pydantic-settings field names (uppercased).
opencode.upsert_mcp "ogham" "$(cat <<JSON
{
  "type": "local",
  "command": ["uvx", "--with", "ogham-mcp[postgres,rerank]", "ogham-mcp"],
  "enabled": true,
  "environment": {
    "DATABASE_BACKEND": "postgres",
    "DATABASE_URL": "{file:.ai/adk/secrets/ogham-database-url}",
    "EMBEDDING_PROVIDER": "ollama",
    "OLLAMA_URL": "http://localhost:11434",
    "OLLAMA_EMBED_MODEL": "nomic-embed-text",
    "RERANK_ENABLED": "true",
    "RERANK_ALPHA": "0.55"
  }
}
JSON
)"

state.mark "ogham_rerank_installed" 2>/dev/null || true

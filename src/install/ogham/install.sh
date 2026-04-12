#!/usr/bin/env bash
# Install ogham-mcp via uv, write its config, activate the profile,
# register its MCP block in opencode.json, and enable FlashRank reranking.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="${SECRETS_DIR:-$(cd "${INSTALL_PATH}/../.." && pwd)/storage/secrets}"
export SECRETS_DIR
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# ── Install binary ─────────────────────────────────────────────────────────────
header "Ogham MCP"

if ! command -v ogham &>/dev/null; then
  step "Installing ogham-mcp via uv..."
  uv tool install ogham-mcp
  export PATH="$HOME/.local/bin:$PATH"
  log "Ogham installed"
else
  skip "Ogham ($(ogham --version 2>/dev/null || echo 'installed'))"
fi

# ── Write ogham config ─────────────────────────────────────────────────────────
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${OGHAM_PROFILE:?OGHAM_PROFILE is required}"
# ogham reads config.toml from ~/.config/ogham/ — this is ogham's own convention
OGHAM_CONFIG_DIR="$HOME/.config/ogham"
mkdir -p "${OGHAM_CONFIG_DIR}"

sed \
  -e "s/{{POSTGRES_PASSWORD}}/${POSTGRES_PASSWORD}/g" \
  -e "s/{{OGHAM_PROFILE}}/${OGHAM_PROFILE}/g" \
  "${SCRIPT_DIR}/config.toml.tmpl" > "${OGHAM_CONFIG_DIR}/config.toml"
log "Ogham config written → ${OGHAM_CONFIG_DIR}/config.toml"

if ogham health &>/dev/null 2>&1; then
  log "Ogham ↔ Postgres: connected"
else
  warn "Ogham health check failed — Postgres may still be warming up. Run 'ogham health' to verify."
fi

step "Activating profile: ${OGHAM_PROFILE}"
ogham use "${OGHAM_PROFILE}" 2>/dev/null || true
log "Profile: ${OGHAM_PROFILE}"

# ── Write database URL secret ─────────────────────────────────────────────────
secrets.write "ogham-database-url" "postgresql://ogham:${POSTGRES_PASSWORD}@localhost:5432/ogham"

# ── Register MCP server in opencode.json ──────────────────────────────────────
opencode.upsert_mcp "ogham" "$(cat <<JSON
{
  "type": "local",
  "command": ["uvx", "ogham-mcp"],
  "enabled": true,
  "environment": {
    "DATABASE_BACKEND": "postgres",
    "DATABASE_URL": "{file:storage/secrets/ogham-database-url}",
    "EMBEDDING_PROVIDER": "ollama",
    "OLLAMA_MODEL": "nomic-embed-text",
    "OLLAMA_BASE_URL": "http://localhost:11434"
  }
}
JSON
)"

# ── Enable FlashRank reranking ─────────────────────────────────────────────────
if state.done "ogham_rerank_installed"; then
  skip "Ogham reranking (already installed)"
else
  step "Installing ogham-mcp[rerank] (FlashRank cross-encoder)..."
  if command -v uv &>/dev/null; then
    uv tool install "ogham-mcp[rerank]" 2>/dev/null \
      || uv tool upgrade ogham-mcp --extra rerank 2>/dev/null \
      || warn "Could not install rerank extra — try: uv tool install 'ogham-mcp[rerank]'"
  else
    pip install "ogham-mcp[rerank]" --break-system-packages 2>/dev/null \
      || warn "Could not install rerank extra"
  fi

  opencode.set_mcp_env "ogham" "RERANK_ENABLED" "true"
  opencode.set_mcp_env "ogham" "RERANK_ALPHA"   "0.55"

  state.mark "ogham_rerank_installed"
  log "FlashRank reranking enabled (RERANK_ALPHA=0.55)"
  info "Cross-encoder adds ~300ms per search. Improves MRR by ~8pp."
fi

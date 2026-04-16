#!/usr/bin/env bash
# Install QMD (Query Markup Documents — semantic search for Markdown vaults)
# via npm, and download the upstream QMD skill into
# src/skills/memory/qmd/SKILL.md so it is available to all initialized projects
# via the .opencode/skills/adk symlink.
#
# QMD's cache location is controlled by XDG_CACHE_HOME.  This ADK redirects it
# to <adk-root>/storage so the index and model files live alongside all other ADK
# runtime data instead of in the system-wide ~/.cache directory:
#   storage/qmd/index.sqlite   — the search index
#   storage/qmd/models/        — GGUF model cache (~2 GB, downloaded on first use)
#
# The absolute storage path is written to storage/secrets/qmd-cache-home so that
# opencode.jsonc can inject it as XDG_CACHE_HOME for the `qmd mcp` server.
#
# Models auto-downloaded on first use (~2 GB total):
#   - 300 MB  embeddinggemma   (embedding)
#   - 640 MB  qwen3-reranker   (reranker)
#   - 1.1 GB  qmd-query-expansion (query expansion)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# ── Install QMD binary ─────────────────────────────────────────────────────────
header "QMD (semantic vault search)"

if ! command -v qmd &>/dev/null; then
  step "Installing QMD via npm..."
  npm install -g @tobilu/qmd
  log "QMD installed"
else
  skip "QMD ($(XDG_CACHE_HOME="${ADK_ROOT}/storage" qmd --version 2>/dev/null || echo 'installed'))"
fi

# ── Write storage path to secrets so opencode.jsonc can reference it ──────────
# opencode resolves {file:.ai/adk/secrets/qmd-cache-home} relative to the project
# root (where opencode.jsonc is symlinked). The symlink .ai/adk/secrets →
# <adk-root>/storage/secrets makes this file visible from every project.
QMD_CACHE_SECRET="${ADK_ROOT}/storage/secrets/qmd-cache-home"
mkdir -p "${ADK_ROOT}/storage/secrets"

if [[ -f "${QMD_CACHE_SECRET}" ]] && [[ "$(cat "${QMD_CACHE_SECRET}")" == "${ADK_ROOT}/storage" ]]; then
  skip "storage/secrets/qmd-cache-home (already correct)"
else
  printf '%s' "${ADK_ROOT}/storage" > "${QMD_CACHE_SECRET}"
  log "Written storage/secrets/qmd-cache-home → ${ADK_ROOT}/storage"
fi

# ── Download QMD agent skill into src/skills/memory/qmd/ ──────────────────────
# The skill teaches agents to use QMD proactively before reading vault files,
# before creating notes (duplicate check), and after creating notes (find related).
# It reaches all initialized projects via the .opencode/skills/adk → src/skills
# symlink created by bin/init.sh.
SKILL_URL="https://raw.githubusercontent.com/tobi/obsidian-mind/main/.claude/skills/qmd/SKILL.md"
SKILL_DIR="${ADK_ROOT}/src/skills/memory/qmd"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

step "Downloading QMD skill → src/skills/memory/qmd/SKILL.md ..."
mkdir -p "${SKILL_DIR}"
if curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null; then
  log "QMD skill downloaded → src/skills/memory/qmd/SKILL.md"
else
  warn "QMD skill download failed — will use bundled ADK skill at ${SKILL_FILE}"
  warn "To retry manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"
fi

# ── Register QMD MCP server in opencode.jsonc ─────────────────────────────────
# The {file:.ai/adk/secrets/qmd-cache-home} reference is resolved by opencode
# relative to the project root (where opencode.jsonc is symlinked). The symlink
# .ai/adk/secrets → <adk-root>/storage/secrets makes the secret visible there.
step "Registering QMD MCP in storage/opencode.jsonc ..."
opencode.upsert_mcp "qmd" \
  '{"type":"local","command":["qmd","mcp"],"enabled":true,"environment":{"XDG_CACHE_HOME":"{file:.ai/adk/secrets/qmd-cache-home}"}}'
log "QMD MCP registered"

info "Run 'make init PROJ=<path>' to register QMD collections for a project (initial embed can take a few minutes)."

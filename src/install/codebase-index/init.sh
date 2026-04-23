#!/usr/bin/env bash
# Write .opencode/codebase-index.json in the current project directory.
# Idempotent: skipped if the file already exists.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "opencode-codebase-index Config"

INDEX_CONFIG="$(pwd)/.opencode/codebase-index.json"

if [[ -f "${INDEX_CONFIG}" ]]; then
  skip "codebase-index config (already exists)"; exit 0
fi

mkdir -p "$(pwd)/.opencode"
cp "${SCRIPT_DIR}/codebase-index.json" "${INDEX_CONFIG}"
log "codebase-index config written → .opencode/codebase-index.json"

# ── Build initial codebase index ─────────────────────────────────────────────
if [[ -d "$(pwd)/.opencode/codebase-index" ]]; then
  skip "Codebase index (already exists)"
elif ! command -v opencode &>/dev/null; then
  info "opencode not found — index will be built on first session"
elif ! curl -sf http://127.0.0.1:17434/v1/models >/dev/null 2>&1; then
  info "Ollama not reachable — index will be built on first session"
else
  step "Building initial codebase index..."
  opencode run --dangerously-skip-permissions \
    "Call the codebase-index index_codebase tool to build the semantic codebase index. Do nothing else. Do not read any files. Just call index_codebase and report the result." \
    && log "Codebase index built" \
    || warn "Codebase index build failed — the agent will build it on first session"
fi

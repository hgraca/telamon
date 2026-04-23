#!/usr/bin/env bash
# Rebuild missing codebase indices for all initialized projects.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Codebase Index"

if ! command -v opencode &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  codebase-index (opencode not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

if ! curl -sf http://127.0.0.1:17434/v1/models >/dev/null 2>&1; then
  warn "Ollama not reachable — skipping codebase index rebuild"
  exit 0
fi

# ── Rebuild missing indices for initialized projects ─────────────────────────
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
for storage_dir in "${TELAMON_ROOT}/storage/graphify"/*/; do
  [[ -d "${storage_dir}" ]] || continue
  [[ -f "${storage_dir}.project-path" ]] || continue
  proj="$(cat "${storage_dir}.project-path")"
  [[ -d "${proj}" ]] || { warn "Project directory not found: ${proj} — skipping"; continue; }
  [[ -d "${proj}/.opencode/codebase-index" ]] && continue
  [[ -f "${proj}/.opencode/codebase-index.json" ]] || continue
  step "Building missing codebase index for $(basename "${proj}")..."
  (cd "${proj}" && opencode run --dangerously-skip-permissions \
    "Call the codebase-index index_codebase tool to build the semantic codebase index. Do nothing else. Just call index_codebase and report the result." 2>&1) \
    || warn "codebase-index build failed for ${proj} — continuing"
done

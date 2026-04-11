#!/usr/bin/env bash
# Install ogham-mcp[rerank] (FlashRank cross-encoder) and enable reranking
# in the OpenCode MCP config.
# Idempotent: skipped if state flag 'ogham_rerank_installed' is set.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Ogham FlashRank Reranking"

if state.done "ogham_rerank_installed"; then
  skip "Ogham reranking (already installed)"; exit 0
fi

step "Installing ogham-mcp[rerank] (FlashRank cross-encoder)..."
if command -v uv &>/dev/null; then
  uv tool install "ogham-mcp[rerank]" 2>/dev/null \
    || uv tool upgrade ogham-mcp --extra rerank 2>/dev/null \
    || warn "Could not install rerank extra — try: uv tool install 'ogham-mcp[rerank]'"
else
  pip install "ogham-mcp[rerank]" --break-system-packages 2>/dev/null \
    || warn "Could not install rerank extra"
fi

# Add rerank env vars to opencode.json ogham environment block
CONFIG_FILE="$HOME/.config/opencode/opencode.json"
if [[ -f "${CONFIG_FILE}" ]]; then
  python3 - "${CONFIG_FILE}" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
env = d.get('mcp', {}).get('ogham', {}).get('environment', {})
env['RERANK_ENABLED'] = 'true'
env['RERANK_ALPHA'] = '0.55'
d['mcp']['ogham']['environment'] = env
with open(path, 'w') as f:
    json.dump(d, f, indent=2)
print("  \033[32m✔\033[0m  Reranking env vars added to opencode.json")
PYEOF
fi

state.mark "ogham_rerank_installed"
log "FlashRank reranking enabled (RERANK_ALPHA=0.55)"
info "Cross-encoder adds ~300ms per search. Improves MRR by ~8pp."

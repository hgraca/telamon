#!/usr/bin/env bash
# Write .opencode/codebase-index.json in the current project directory.
# Idempotent: skipped if the file already exists.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "opencode-codebase-index Config"

INDEX_CONFIG="$(pwd)/.opencode/codebase-index.json"

if [[ -f "${INDEX_CONFIG}" ]]; then
  skip "codebase-index config (already exists)"; exit 0
fi

mkdir -p "$(pwd)/.opencode"
cat > "${INDEX_CONFIG}" <<JSON
{
  "embeddingProvider": "ollama",
  "indexing": {
    "autoIndex": true,
    "watchFiles": true,
    "maxFileSize": 1048576,
    "maxChunksPerFile": 100,
    "autoGc": true,
    "gcIntervalDays": 7
  },
  "search": {
    "maxResults": 20,
    "minScore": 0.1,
    "hybridWeight": 0.6,
    "fusionStrategy": "rrf",
    "rrfK": 60,
    "rerankTopN": 20
  }
}
JSON
log "codebase-index config written → .opencode/codebase-index.json"
info "Run /index inside OpenCode to build the initial codebase index."

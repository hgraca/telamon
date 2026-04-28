#!/usr/bin/env bash
# Verify npx is available. promptfoo runs via npx — no global install needed.
# No MCP registration — promptfoo is a CLI tool, not an MCP server.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "promptfoo (Agent Evaluation)"

if ! command -v npx &>/dev/null; then
  fail "npx not found — install Node.js first"
  exit 1
fi

log "promptfoo available via npx (npx -y promptfoo)"

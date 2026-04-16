#!/usr/bin/env bash
# Register the opencode-codebase-index MCP server in ~/.config/opencode/opencode.json.
# The server runs via npx — no binary installation required.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "codebase-index MCP"

opencode.upsert_mcp "codebase-index" '{
  "type": "local",
  "command": ["npx", "-y", "-p", "opencode-codebase-index", "-p", "@modelcontextprotocol/sdk", "opencode-codebase-index-mcp", "--project", "."],
  "enabled": true
}'

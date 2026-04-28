#!/usr/bin/env bash
# Register the repomix MCP server in ~/.config/opencode/opencode.json.
# The server runs via npx — no binary installation required.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Repomix MCP"

opencode.upsert_mcp "repomix" '{
  "type": "local",
  "command": ["npx", "-y", "repomix", "--mcp"],
  "enabled": true
}'

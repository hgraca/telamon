#!/usr/bin/env bash
# Register the Obsidian MCP server in ~/.config/opencode/opencode.json.
#
# Obsidian itself must be installed manually (obsidian.md).
# The Local REST API plugin must be enabled and its API key provided via
# the OBSIDIAN_API_KEY environment variable.
#
# Required env vars:
#   OBSIDIAN_API_KEY — Obsidian Local REST API key

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SECRETS_DIR="${SECRETS_DIR:-$(cd "${INSTALL_PATH}/../.." && pwd)/storage/secrets}"
export SECRETS_DIR
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

: "${OBSIDIAN_API_KEY:?OBSIDIAN_API_KEY is required}"

header "Obsidian MCP"

# host.docker.internal resolves to the host on both macOS and Linux
OBS_HOST="host.docker.internal"

# ── Write API key secret ───────────────────────────────────────────────────────
secrets.write "obsidian-api-key" "${OBSIDIAN_API_KEY}"

opencode.upsert_mcp "obsidian" "$(cat <<JSON
{
  "type": "local",
  "command": [
    "docker", "run", "--rm", "-i",
    "-e", "API_KEY",
    "-e", "API_URLS",
    "oleksandrkucherenko/obsidian-mcp:latest"
  ],
  "enabled": true,
  "environment": {
    "API_KEY": "{file:storage/secrets/obsidian-api-key}",
    "API_URLS": "[\"https://${OBS_HOST}:27124\"]"
  }
}
JSON
)"

if [[ "${OBSIDIAN_API_KEY}" == "REPLACE_WITH_OBSIDIAN_API_KEY" ]]; then
  warn "Obsidian API key is a placeholder — update it when you have the real key."
  info "Obsidian → Settings → Community Plugins → Local REST API → copy the key."
  info "Re-run this installer after setting the key in .env."
fi

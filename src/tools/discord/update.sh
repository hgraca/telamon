#!/usr/bin/env bash
# Update the Discord bot (remote-opencode npm package).
# Exit codes: 0=success  1=failed  2=not-enabled (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Discord Bot (remote-opencode)"

env.is_enabled DISCORD_ENABLED || {
  echo -e "  ${TEXT_DIM}–  Discord Bot (disabled — skipping)${TEXT_CLEAR}"
  exit 2
}

if ! command -v remote-opencode >/dev/null 2>&1; then
  warn "remote-opencode not found — run: npm install -g remote-opencode"
  exit 1
fi

step "Updating remote-opencode..."
npm update -g remote-opencode \
  && log "remote-opencode → updated" \
  || { warn "npm update -g remote-opencode failed"; exit 1; }

#!/usr/bin/env bash
# Update the Discord bridge Docker image.
# Exit codes: 0=success  1=failed  2=not-enabled (skipped)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Discord Bridge (opencode-chat-bridge)"

env.is_enabled DISCORD_BRIDGE_ENABLED || {
  echo -e "  ${TEXT_DIM}–  Discord Bridge (disabled — skipping)${TEXT_CLEAR}"
  exit 2
}

step "Pulling latest lbecchi/opencode-chat-bridge image..."
docker pull lbecchi/opencode-chat-bridge \
  && log "lbecchi/opencode-chat-bridge → updated" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  docker pull failed"; exit 1; }

#!/usr/bin/env bash
# Update Docker images via docker compose pull.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Docker images"

if ! command -v docker &>/dev/null || ! docker info &>/dev/null 2>&1; then
  echo -e "  ${TEXT_DIM}–  Docker (not running — skipping)${TEXT_CLEAR}"
  exit 2
fi

step "Pulling latest Docker images..."
(cd "${TELAMON_ROOT}" && docker compose pull) \
  && log "Docker images updated" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  Docker image pull failed"; exit 1; }

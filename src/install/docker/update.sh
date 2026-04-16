#!/usr/bin/env bash
# Update Docker images via docker compose pull.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Docker images"

if ! command -v docker &>/dev/null || ! docker info &>/dev/null 2>&1; then
  echo -e "  ${TEXT_DIM}–  Docker (not running — skipping)${TEXT_CLEAR}"
  exit 2
fi

step "Pulling latest Docker images..."
(cd "${TELAMON_ROOT}" && docker compose pull --quiet 2>/dev/null) \
  && log "Docker images updated" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  Docker image pull failed"; exit 1; }

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

# Capture image IDs before pulling so we can remove only the replaced ones
step "Pulling latest Docker images..."
_OLD_IDS=$(cd "${TELAMON_ROOT}" && docker compose images -q 2>/dev/null | sort -u || true)

(cd "${TELAMON_ROOT}" && docker compose pull) \
  && log "Docker images updated" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  Docker image pull failed"; exit 1; }

# Remove only the old images that were replaced by the pull
_NEW_IDS=$(cd "${TELAMON_ROOT}" && docker compose images -q 2>/dev/null | sort -u || true)
_REPLACED=()
for _id in ${_OLD_IDS}; do
  if ! echo "${_NEW_IDS}" | grep -q "${_id}"; then
    _REPLACED+=("${_id}")
  fi
done

if [[ ${#_REPLACED[@]} -gt 0 ]]; then
  step "Removing ${#_REPLACED[@]} replaced Docker image(s)..."
  docker rmi "${_REPLACED[@]}" >/dev/null 2>&1 \
    && log "Replaced images removed" \
    || info "Some old images could not be removed (may still be in use)"
else
  info "No replaced images to clean up"
fi

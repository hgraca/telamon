#!/usr/bin/env bash
# Write ~/.config/ogham/config.toml and activate the Ogham profile.
#
# Required env vars:
#   POSTGRES_PASSWORD  — Postgres password
#   OGHAM_PROFILE      — profile name for this project
#   STATE_DIR          — state directory (default: ~/.config/ogham)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${OGHAM_PROFILE:?OGHAM_PROFILE is required}"
STATE_DIR="${STATE_DIR:-$HOME/.config/ogham}"

header "Ogham Config & Profile"

cat > "${STATE_DIR}/config.toml" <<TOML
[database]
backend = "postgres"
url = "postgresql://ogham:${POSTGRES_PASSWORD}@localhost:5432/ogham"

[embedding]
provider = "ollama"
model = "nomic-embed-text"
url = "http://localhost:11434"

[profile]
default = "${OGHAM_PROFILE}"
TOML
log "Ogham config written → ${STATE_DIR}/config.toml"

if ogham health &>/dev/null 2>&1; then
  log "Ogham ↔ Postgres: connected"
else
  warn "Ogham health check failed — Postgres may still be warming up. Run 'ogham health' to verify."
fi

step "Activating profile: ${OGHAM_PROFILE}"
ogham use "${OGHAM_PROFILE}" 2>/dev/null || true
log "Profile: ${OGHAM_PROFILE}"

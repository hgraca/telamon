#!/usr/bin/env bash
# Install the global ~/.config/opencode/AGENTS.md file.
# Idempotent: skipped if the file already exists.
#
# Reads template from: src/install/opencode/global-AGENTS.md

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Global AGENTS.md"

AGENTS_FILE="$HOME/.config/opencode/AGENTS.md"
mkdir -p "$HOME/.config/opencode"

if [[ -f "${AGENTS_FILE}" ]]; then
  skip "Global AGENTS.md (already exists)"; exit 0
fi

cp "${SCRIPT_DIR}/global-AGENTS.md" "${AGENTS_FILE}"
log "Global AGENTS.md written → ${AGENTS_FILE}"

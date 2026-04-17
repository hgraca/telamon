#!/usr/bin/env bash
# Install a scheduled job that runs `cass index` (incremental) every 30 minutes,
# keeping the session search index current automatically.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "cass scheduled index"

if ! command -v cass &>/dev/null; then
  warn "cass not found — skipping scheduled index installation"
  return 0 2>/dev/null || exit 0
fi

bash "${INSTALL_PATH}/cass/schedule.sh" || warn "cass schedule.sh failed — skipping scheduled index"

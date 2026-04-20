#!/usr/bin/env bash
set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "promptfoo"

ver=$(npx -y promptfoo --version 2>/dev/null) || true
if [[ -n "${ver}" ]]; then
  log "promptfoo ${ver}"
else
  fail "promptfoo: npx -y promptfoo --version failed"
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Repomix"

ver=$(npx -y repomix --version 2>/dev/null) || true
if [[ -n "${ver}" ]]; then
  log "Repomix ${ver}"
else
  fail "Repomix: npx -y repomix --version failed"
  exit 1
fi

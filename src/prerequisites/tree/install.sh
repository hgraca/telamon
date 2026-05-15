#!/usr/bin/env bash
# Ensure tree is installed — required by Telamon for the tree-report tool.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "tree"

if command -v tree &>/dev/null; then
  skip "tree ($(tree --version 2>/dev/null | head -1 || echo 'installed'))"
else
  OS=$(os.get_os)
  if [[ "${OS}" == "macos" ]]; then
    step "Installing tree via Homebrew..."
    brew install tree
  else
    step "Installing tree via apt..."
    apt.install tree
  fi
  log "tree installed ($(tree --version 2>/dev/null | head -1))"
fi

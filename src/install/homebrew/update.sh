#!/usr/bin/env bash
# Update Homebrew.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Package managers"

if ! command -v brew &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  Homebrew (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

step "Updating Homebrew..."
brew update --quiet 2>/dev/null && log "Homebrew updated" || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  Homebrew update failed"; exit 1; }

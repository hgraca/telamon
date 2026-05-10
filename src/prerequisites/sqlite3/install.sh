#!/usr/bin/env bash
# Install sqlite3 — required by the stats CLI (`telamon stats`) which queries
# the tool-usage database at storage/stats/stats.sqlite via the `sqlite3` binary.
#
# The stats plugin itself uses bun's built-in SQLite for writing, but the
# stats-query.sh script invokes the system `sqlite3` command for CSV export.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "sqlite3"

if command -v sqlite3 &>/dev/null; then
  skip "sqlite3 ($(sqlite3 --version | awk '{print $1}'))"
  exit 0
fi

OS=$(os.get_os)

if [[ "${OS}" == "macos" ]]; then
  step "Installing sqlite3 via Homebrew..."
  brew install sqlite
else
  step "Installing sqlite3 via apt..."
  apt.install sqlite3
fi

log "sqlite3 installed ($(sqlite3 --version | awk '{print $1}'))"

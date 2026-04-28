#!/usr/bin/env bash
# Writes shell environment entries (PATH, OGHAM_PROFILE, OBSIDIAN_API_KEY)
# and the QMD wrapper function to the user's shell RC file.
# Thin entry point so bin/install.sh can call this as install.sh like all
# other app installers.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export TOOLS_PATH FUNCTIONS_PATH

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

bash "${FUNCTIONS_PATH}/write-env.sh"

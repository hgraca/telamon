#!/usr/bin/env bash
# Writes shell environment entries (PATH, OGHAM_PROFILE, OBSIDIAN_API_KEY)
# and the QMD wrapper function to the user's shell RC file.
# Thin entry point so bin/install.sh can call this as install.sh like all
# other app installers.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export INSTALL_PATH

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

bash "${INSTALL_PATH}/shell/write-env.sh"

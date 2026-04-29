#!/usr/bin/env bash
# Session-capture project setup.
#
# The plugin entry (".opencode/plugins/telamon/session-capture.js") is already
# present in storage/opencode.jsonc (added during `make install`). Projects receive
# the plugin JS via the .opencode/plugins/telamon symlink created by `make init`.
# No per-project copying or configuration is required.
#
# This script is intentionally empty; it exists as a placeholder in case
# future per-project setup steps are added for the session-capture plugin.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Session Capture"

skip "No per-project setup required (plugin delivered via .opencode/plugins/telamon symlink)"

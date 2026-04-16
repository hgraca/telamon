#!/usr/bin/env bash
# Session-capture project setup.
#
# The plugin entry (".opencode/plugins/adk/session-capture.js") is already
# present in storage/opencode.jsonc (added during `make up`). Projects receive
# the plugin JS via the .opencode/plugins/adk symlink created by `make init`.
# No per-project copying or configuration is required.
#
# This script is intentionally empty; it exists as a placeholder in case
# future per-project setup steps are added for the session-capture plugin.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Session Capture"

skip "No per-project setup required (plugin delivered via .opencode/plugins/adk symlink)"

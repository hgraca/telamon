#!/usr/bin/env bash
# Install the session-capture OpenCode plugin in the current project.
#
# The plugin hooks into experimental.session.compacting to inject the
# session-capture skill before the LLM generates a compaction summary.
# This ensures session learnings are captured to the Obsidian vault before
# context is discarded.
#
# The plugin entry ("session-capture") is already present in
# storage/opencode.jsonc (added during `make up`). For projects with their own
# opencode config it flows in via merge-config.py in bin/init.sh.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Session Capture"

PLUGIN_SRC="${SCRIPT_DIR}/session-capture.js"
PLUGIN_DEST=".opencode/plugins/session-capture.js"

mkdir -p ".opencode/plugins"
if [[ -f "${PLUGIN_DEST}" ]]; then
  skip "${PLUGIN_DEST} (already exists)"
else
  cp "${PLUGIN_SRC}" "${PLUGIN_DEST}"
  log "Copied session-capture plugin → ${PLUGIN_DEST}"
fi

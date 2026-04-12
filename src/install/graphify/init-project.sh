#!/usr/bin/env bash
# Set up Graphify in the current project: redirect graphify-out to
# storage/graphify, copy the OpenCode plugin JS, and install git hooks.
#
# graphify always writes to ./graphify-out relative to CWD. We redirect it
# to <adk-root>/storage/graphify via a symlink so all output is centralised
# and never scattered across the project tree.
#
# The plugin entry (".opencode/plugins/graphify.js") is already present in
# storage/opencode.jsonc (added by graphify/install.sh during `make up`).
# For projects with their own opencode config it flows in via merge-config.py
# in bin/init.sh. No separate opencode.json is written here.
#
# The graphify skill is shipped as a static file in src/skills/graphify/SKILL.md
# and is made available to projects via the .opencode/skills/adk symlink created
# by `make init`. No download or copying is needed.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Graphify"

if ! command -v graphify &>/dev/null; then
  warn "graphify not found — skipping project setup"
  return 0 2>/dev/null || exit 0
fi

# ── Redirect graphify-out → <adk-root>/storage/graphify ──────────────────────
# graphify hardcodes ./graphify-out as its output directory. A symlink at the
# project root redirects all output to the ADK's central storage location.
GRAPHIFY_STORAGE="${ADK_ROOT}/storage/graphify"
mkdir -p "${GRAPHIFY_STORAGE}"

if [[ -L "graphify-out" ]]; then
  skip "graphify-out symlink (already exists)"
elif [[ -d "graphify-out" ]]; then
  warn "graphify-out is a real directory — moving contents to storage/graphify and replacing with symlink"
  cp -r graphify-out/. "${GRAPHIFY_STORAGE}/"
  rm -rf graphify-out
  ln -s "${GRAPHIFY_STORAGE}" graphify-out
  log "graphify-out → ${GRAPHIFY_STORAGE}"
else
  ln -s "${GRAPHIFY_STORAGE}" graphify-out
  log "Symlinked graphify-out → ${GRAPHIFY_STORAGE}"
fi

# ── Copy plugin JS into project ───────────────────────────────────────────────
PLUGIN_SRC="${SCRIPT_DIR}/graphify.js"
PLUGIN_DEST=".opencode/plugins/graphify.js"

mkdir -p ".opencode/plugins"
if [[ -f "${PLUGIN_DEST}" ]]; then
  skip "${PLUGIN_DEST} (already exists)"
else
  cp "${PLUGIN_SRC}" "${PLUGIN_DEST}"
  log "Copied graphify plugin → ${PLUGIN_DEST}"
fi

# ── Install git hooks ─────────────────────────────────────────────────────────
step "Installing graphify git hooks..."
graphify hook install 2>/dev/null || true
log "Graphify git hooks installed"

info "Run 'graphify .' to build the initial knowledge graph."

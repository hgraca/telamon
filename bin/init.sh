#!/usr/bin/env bash
# =============================================================================
# bin/init.sh
# Initialise a project to use Telamon.
#
# Usage:
#   bin/init.sh <path/to/project>
#
# What it does (delegated to per-app init scripts):
#   obsidian      — vault scaffold + .ai/telamon/memory symlink
#   opencode      — skills symlink, plugins symlink, telamon.ini, secrets
#                   symlink, opencode.jsonc symlink/merge, AGENTS.md
#   codebase-index — writes .opencode/codebase-index.json
#   graphify      — graphify-out symlink + MCP wrapper + scheduled updates
#   cass          — scheduled index updates (every 30 min)
#   qmd           — vault collections + initial semantic index
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${TELAMON_ROOT}/src/install"

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# ── Argument ──────────────────────────────────────────────────────────────────
PROJ="${1:-}"
if [[ -z "${PROJ}" ]]; then
  echo "Usage: $0 <path/to/project>" >&2
  exit 1
fi

if [[ ! -d "${PROJ}" ]]; then
  echo "Error: project path does not exist: ${PROJ}" >&2
  exit 1
fi

PROJ="$(cd "${PROJ}" && pwd)"
PROJECT_NAME="$(basename "${PROJ}")"

export TELAMON_ROOT INSTALL_PATH PROJ PROJECT_NAME

header "Telamon init — ${PROJECT_NAME}"

# ── Run per-app init scripts ──────────────────────────────────────────────────
INIT_APPS=(obsidian opencode codebase-index graphify cass qmd session-capture)

for _app in "${INIT_APPS[@]}"; do
  _script="${INSTALL_PATH}/${_app}/init.sh"
  if [[ ! -f "${_script}" ]]; then
    warn "No init.sh for ${_app} — skipping"
    continue
  fi
  (cd "${PROJ}" && timed_run "${_app}" bash "${_script}")
done

# ── Done ──────────────────────────────────────────────────────────────────────
BRAIN_DIR="${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}/brain"
echo
log "Project '${PROJECT_NAME}' initialised."
info "Memory notes: ${BRAIN_DIR}/"
info "Edit ${BRAIN_DIR}/memories.md to record project lessons."
echo -e "  ${TEXT_DIM}⏱  Total init time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"

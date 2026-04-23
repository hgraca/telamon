#!/usr/bin/env bash
# =============================================================================
# bin/init.sh
# Initialise a project to use Telamon.
#
# Usage:
#   bin/init.sh [--memory-owner=telamon|project] <path/to/project>
#
# What it does (delegated to per-app init scripts):
#   obsidian      — vault scaffold + .ai/telamon/memory symlink
#   opencode      — skills symlink, plugins symlink, telamon.ini, secrets
#                   symlink, opencode.jsonc symlink/merge, AGENTS.md
#   codebase-index — writes .opencode/codebase-index.json
#   repomix       — writes repomix.config.json
#   graphify      — graphify-out symlink + MCP wrapper + scheduled updates
#   qmd           — vault collections + initial semantic index
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${TELAMON_ROOT}/src/install"

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# ── Flag parsing ──────────────────────────────────────────────────────────────
MEMORY_OWNER_FLAG=""
POSITIONAL_ARGS=()

for _arg in "$@"; do
  case "${_arg}" in
    --memory-owner=*)
      MEMORY_OWNER_FLAG="${_arg#--memory-owner=}"
      ;;
    *)
      POSITIONAL_ARGS+=("${_arg}")
      ;;
  esac
done

# ── Argument ──────────────────────────────────────────────────────────────────
PROJ="${POSITIONAL_ARGS[0]:-}"
if [[ -z "${PROJ}" ]]; then
  echo "Usage: $0 [--memory-owner=telamon|project] <path/to/project>" >&2
  exit 1
fi

if [[ ! -d "${PROJ}" ]]; then
  echo "Error: project path does not exist: ${PROJ}" >&2
  exit 1
fi

PROJ="$(cd "${PROJ}" && pwd)"
PROJECT_NAME="$(basename "${PROJ}")"

# ── Resolve MEMORY_OWNER ──────────────────────────────────────────────────────
# Priority: CLI flag > existing telamon.ini > interactive prompt > default (telamon)
MEMORY_OWNER=""

if [[ -n "${MEMORY_OWNER_FLAG}" ]]; then
  # Validate flag value
  if [[ "${MEMORY_OWNER_FLAG}" != "telamon" && "${MEMORY_OWNER_FLAG}" != "project" ]]; then
    echo "Error: --memory-owner must be 'telamon' or 'project', got: ${MEMORY_OWNER_FLAG}" >&2
    exit 1
  fi
  MEMORY_OWNER="${MEMORY_OWNER_FLAG}"
else
  # Check existing telamon.ini (re-init scenario)
  _ini_file="${PROJ}/.ai/telamon/telamon.ini"
  if [[ -f "${_ini_file}" ]]; then
    _existing="$(config.read_ini "${_ini_file}" "memory_owner" 2>/dev/null || true)"
    if [[ -n "${_existing}" ]]; then
      MEMORY_OWNER="${_existing}"
    fi
  fi

  # Interactive prompt if still unset and stdin is a TTY
  if [[ -z "${MEMORY_OWNER}" ]]; then
    if [[ -t 0 ]]; then
      echo
      echo "? Memory file ownership for ${PROJECT_NAME}:"
      echo "  1) telamon — files in Telamon storage, symlink in project (default)"
      echo "  2) project — files in project, symlink in Telamon storage"
      echo
      printf "? Your choice [1-2]: "
      read -r _choice
      case "${_choice}" in
        2) MEMORY_OWNER="project" ;;
        *) MEMORY_OWNER="telamon" ;;
      esac
    else
      MEMORY_OWNER="telamon"
    fi
  fi
fi

export TELAMON_ROOT INSTALL_PATH PROJ PROJECT_NAME MEMORY_OWNER

header "Telamon init — ${PROJECT_NAME}"

# ── Run per-app init scripts ──────────────────────────────────────────────────
INIT_APPS=(obsidian opencode codebase-index repomix promptfoo graphify qmd session-capture)

for _app in "${INIT_APPS[@]}"; do
  _script="${INSTALL_PATH}/${_app}/init.sh"
  if [[ ! -f "${_script}" ]]; then
    warn "No init.sh for ${_app} — skipping"
    continue
  fi
  (cd "${PROJ}" && timed_run "${_app}" bash "${_script}")
done

# ── Done ──────────────────────────────────────────────────────────────────────
if [[ "${MEMORY_OWNER}" == "project" ]]; then
  BRAIN_DIR="${PROJ}/.ai/telamon/memory/brain"
else
  BRAIN_DIR="${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}/brain"
fi
echo
log "Project '${PROJECT_NAME}' initialised."
info "Memory notes: ${BRAIN_DIR}/"
info "Edit ${BRAIN_DIR}/memories.md to record project lessons."
echo -e "  ${TEXT_DIM}⏱  Total init time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"

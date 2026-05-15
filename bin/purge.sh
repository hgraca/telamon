#!/usr/bin/env bash
# =============================================================================
# bin/purge.sh
# Remove all project-side wiring (reset) AND project-specific storage data.
#
# Usage:
#   bin/purge.sh <path/to/project>
#
# What it removes (in addition to reset):
#   - storage/memory/projects/<proj>/   (vault directory tree)
#   - storage/graphify/<proj>/   (graph data)
#   - QMD collection: <proj>
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREREQUISITES_PATH="${TELAMON_ROOT}/src/prerequisites"
MODULES_PATH="${TELAMON_ROOT}/src/modules"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

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

export TELAMON_ROOT PREREQUISITES_PATH MODULES_PATH FUNCTIONS_PATH PROJ PROJECT_NAME

header "Telamon purge — ${PROJECT_NAME}"

# Read memory_owner from telamon.jsonc BEFORE reset runs, because reset.sh deletes telamon.jsonc
_MEMORY_OWNER="telamon"
_INI_FILE="${PROJ}/.ai/telamon/telamon.jsonc"
if [[ -f "${_INI_FILE}" ]]; then
  _val="$(config.read_ini "${_INI_FILE}" "memory_owner" 2>/dev/null || true)"
  [[ -n "${_val}" ]] && _MEMORY_OWNER="${_val}"
fi

# ── Step 1: reset project wiring ─────────────────────────────────────────────
step "Running reset first..."
bash "${TELAMON_ROOT}/bin/reset.sh" "${PROJ}"

# ── Step 2: remove vault data ─────────────────────────────────────────────────
header "Removing storage data — ${PROJECT_NAME}"

VAULT_DIR="${TELAMON_ROOT}/storage/memory/projects/${PROJECT_NAME}"
if [[ "${_MEMORY_OWNER}" == "project" ]]; then
  step "Removing storage symlink: storage/memory/projects/${PROJECT_NAME} ..."
  if [[ -L "${VAULT_DIR}" ]]; then
    rm "${VAULT_DIR}"
    log "Removed symlink: storage/memory/projects/${PROJECT_NAME}"
    warn "Project-owned vault at ${PROJ}/.ai/telamon/memory/ left intact"
  else
    skip "storage/memory/projects/${PROJECT_NAME} symlink (not found)"
  fi
else
  step "Removing vault: storage/memory/projects/${PROJECT_NAME}/ ..."
  if [[ -d "${VAULT_DIR}" ]]; then
    rm -rf "${VAULT_DIR}"
    log "Removed vault: storage/memory/projects/${PROJECT_NAME}/"
  else
    skip "storage/memory/projects/${PROJECT_NAME}/ (not found)"
  fi
fi

# ── Step 3: remove graphify data ──────────────────────────────────────────────
GRAPHIFY_DIR="${TELAMON_ROOT}/storage/graphify/${PROJECT_NAME}"
step "Removing graphify data: ${GRAPHIFY_DIR}..."
if [[ -d "${GRAPHIFY_DIR}" ]]; then
  rm -rf "${GRAPHIFY_DIR}"
  log "Removed graphify data: storage/graphify/${PROJECT_NAME}/"
else
  skip "storage/graphify/${PROJECT_NAME}/ (not found)"
fi

# ── Step 4: remove QMD collection ─────────────────────────────────────────────
step "Removing QMD collection..."
export XDG_CACHE_HOME="${TELAMON_ROOT}/storage"

if ! command -v qmd &>/dev/null; then
  warn "qmd not found — skipping QMD collection removal"
else
  name="${PROJECT_NAME}"
  if qmd collection list 2>/dev/null | grep -q "^${name} "; then
    if qmd collection remove "${name}" 2>/dev/null; then
      log "Removed QMD collection: ${name}"
    else
      warn "Failed to remove QMD collection: ${name} — remove manually: qmd collection remove ${name}"
    fi
  else
    skip "QMD collection ${name} (not found)"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo
log "Project '${PROJECT_NAME}' purged. All wiring and storage data removed."
info "Re-run 'make init PROJ=${PROJ}' to start fresh."
echo -e "  ${TEXT_DIM}⏱  Total purge time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"

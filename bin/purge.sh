#!/usr/bin/env bash
# =============================================================================
# bin/purge.sh
# Remove all project-side wiring (reset) AND project-specific storage data.
#
# Usage:
#   bin/purge.sh <path/to/project>
#
# What it removes (in addition to reset):
#   - storage/obsidian/<proj>/   (vault directory tree)
#   - storage/graphify/<proj>/   (graph data)
#   - QMD collections: <proj>-brain, <proj>-work, <proj>-project-rules,
#                      <proj>-reference, <proj>-thinking
#   - Ogham memories for profile <proj> (Postgres)
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_PATH="${TELAMON_ROOT}/src/tools"
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

export TELAMON_ROOT TOOLS_PATH FUNCTIONS_PATH PROJ PROJECT_NAME

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

OBSIDIAN_DIR="${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}"
if [[ "${_MEMORY_OWNER}" == "project" ]]; then
  step "Removing storage symlink: storage/obsidian/${PROJECT_NAME} ..."
  if [[ -L "${OBSIDIAN_DIR}" ]]; then
    rm "${OBSIDIAN_DIR}"
    log "Removed symlink: storage/obsidian/${PROJECT_NAME}"
    warn "Project-owned vault at ${PROJ}/.ai/telamon/memory/ left intact"
  else
    skip "storage/obsidian/${PROJECT_NAME} symlink (not found)"
  fi
else
  step "Removing vault: storage/obsidian/${PROJECT_NAME}/ ..."
  if [[ -d "${OBSIDIAN_DIR}" ]]; then
    rm -rf "${OBSIDIAN_DIR}"
    log "Removed vault: storage/obsidian/${PROJECT_NAME}/"
  else
    skip "storage/obsidian/${PROJECT_NAME}/ (not found)"
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

# ── Step 4: remove QMD collections ────────────────────────────────────────────
step "Removing QMD collections..."
export XDG_CACHE_HOME="${TELAMON_ROOT}/storage"

if ! command -v qmd &>/dev/null; then
  warn "qmd not found — skipping QMD collection removal"
else
  for section in brain work project-rules reference thinking; do
    name="${PROJECT_NAME}-${section}"
    if qmd collection list 2>/dev/null | grep -q "^${name} "; then
      if qmd collection remove "${name}" 2>/dev/null; then
        log "Removed QMD collection: ${name}"
      else
        warn "Failed to remove QMD collection: ${name} — remove manually: qmd collection remove ${name}"
      fi
    else
      skip "QMD collection ${name} (not found)"
    fi
  done
fi

# ── Step 5: remove Ogham memories for project profile ─────────────────────────
step "Removing Ogham memories for profile: ${PROJECT_NAME}..."
if docker exec ogham-postgres psql -U ogham -d ogham -c "DELETE FROM memories WHERE profile = '${PROJECT_NAME}'" 2>/dev/null; then
  log "Removed Ogham memories for profile: ${PROJECT_NAME}"
else
  warn "Failed to remove Ogham memories — Postgres may not be running"
  info "Start services with 'make up' and re-run, or delete manually:"
  info "  docker exec ogham-postgres psql -U ogham -d ogham -c \"DELETE FROM memories WHERE profile = '${PROJECT_NAME}'\""
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo
log "Project '${PROJECT_NAME}' purged. All wiring and storage data removed."
info "Re-run 'make init PROJ=${PROJ}' to start fresh."
echo -e "  ${TEXT_DIM}⏱  Total purge time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"

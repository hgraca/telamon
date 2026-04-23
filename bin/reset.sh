#!/usr/bin/env bash
# =============================================================================
# bin/reset.sh
# Remove all project-side wiring created by `make init`. Keeps all memory
# and data in storage/ (vault, graph, QMD collections).
#
# Usage:
#   bin/reset.sh <path/to/project>
#
# What it removes (project-side only):
#   - .opencode/skills/telamon        symlink
#   - .opencode/plugins/telamon       symlink
#   - .opencode/agents/telamon        symlink
#   - .opencode/commands/telamon      symlink
#   - .opencode/graphify-serve.sh     symlink
#   - .ai/telamon/memory              symlink
#   - .ai/telamon/secrets             symlink
#   - .ai/telamon/scripts             symlink
#   - .ai/telamon/telamon.ini         file
#   - opencode.jsonc                  symlink (warns if merged file)
#   - AGENTS.md                       symlink
#   - graphify-out                    symlink
#   - .opencode/codebase-index.json   file
#   - repomix.config.json             file
#   - graphify-update-<proj> timer    scheduled job
#   - Empty parent dirs (.opencode/, .ai/telamon/, .ai/)
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

header "Telamon reset — ${PROJECT_NAME}"

# ── Helper: remove symlink only ───────────────────────────────────────────────
remove_symlink() {
  local path="$1" label="$2"
  if [[ -L "${path}" ]]; then
    rm "${path}"
    log "Removed symlink: ${label}"
  elif [[ -e "${path}" ]]; then
    skip "${label} (not a symlink — skipping)"
  else
    skip "${label} (not found)"
  fi
}

# ── Helper: remove file ───────────────────────────────────────────────────────
remove_file() {
  local path="$1" label="$2"
  if [[ -f "${path}" ]]; then
    rm "${path}"
    log "Removed: ${label}"
  else
    skip "${label} (not found)"
  fi
}

# ── Helper: remove empty dir ──────────────────────────────────────────────────
remove_if_empty() {
  local dir="$1"
  if [[ -d "${dir}" ]] && [[ -z "$(ls -A "${dir}" 2>/dev/null)" ]]; then
    rmdir "${dir}"
    log "Removed empty dir: ${dir#"${PROJ}/"}"
  fi
}

# ── 1. opencode symlinks ──────────────────────────────────────────────────────
step "Removing opencode symlinks..."
remove_symlink "${PROJ}/.opencode/skills/telamon"   ".opencode/skills/telamon"
remove_symlink "${PROJ}/.opencode/plugins/telamon"  ".opencode/plugins/telamon"
remove_symlink "${PROJ}/.opencode/agents/telamon"   ".opencode/agents/telamon"
remove_symlink "${PROJ}/.opencode/commands/telamon" ".opencode/commands/telamon"
remove_symlink "${PROJ}/.opencode/graphify-serve.sh" ".opencode/graphify-serve.sh"

# ── 2. .ai/telamon symlinks and files ─────────────────────────────────────────
step "Removing .ai/telamon wiring..."

# Read memory_owner before removing telamon.ini
_MEMORY_OWNER="telamon"
_INI_FILE="${PROJ}/.ai/telamon/telamon.ini"
if [[ -f "${_INI_FILE}" ]]; then
  _val="$(config.read_ini "${_INI_FILE}" "memory_owner" 2>/dev/null || true)"
  [[ -n "${_val}" ]] && _MEMORY_OWNER="${_val}"
fi

if [[ "${_MEMORY_OWNER}" == "project" ]]; then
  # Project mode: symlink is on the storage side; project dir is real
  _STORAGE_LINK="${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}"
  remove_symlink "${_STORAGE_LINK}" "storage/obsidian/${PROJECT_NAME} (telamon-side symlink)"
  warn ".ai/telamon/memory/ is a project-owned directory — left intact"
else
  # Telamon mode (default): symlink is on the project side
  remove_symlink "${PROJ}/.ai/telamon/memory" ".ai/telamon/memory"
fi

remove_symlink "${PROJ}/.ai/telamon/secrets" ".ai/telamon/secrets"
remove_symlink "${PROJ}/.ai/telamon/scripts" ".ai/telamon/scripts"
remove_file    "${PROJ}/.ai/telamon/telamon.ini" ".ai/telamon/telamon.ini"

# ── 3. opencode.jsonc ─────────────────────────────────────────────────────────
step "Removing opencode.jsonc..."
OPENCODE_JSONC="${PROJ}/opencode.jsonc"
OPENCODE_JSON="${PROJ}/opencode.json"
if [[ -L "${OPENCODE_JSONC}" ]]; then
  rm "${OPENCODE_JSONC}"
  log "Removed symlink: opencode.jsonc"
elif [[ -f "${OPENCODE_JSONC}" ]]; then
  warn "opencode.jsonc is a merged file — Telamon settings must be removed manually"
elif [[ -L "${OPENCODE_JSON}" ]]; then
  rm "${OPENCODE_JSON}"
  log "Removed symlink: opencode.json"
elif [[ -f "${OPENCODE_JSON}" ]]; then
  warn "opencode.json is a merged file — Telamon settings must be removed manually"
else
  skip "opencode.jsonc (not found)"
fi

# ── 4. AGENTS.md ──────────────────────────────────────────────────────────────
step "Removing AGENTS.md..."
remove_symlink "${PROJ}/AGENTS.md" "AGENTS.md"

# ── 5. graphify-out ───────────────────────────────────────────────────────────
step "Removing graphify-out symlink..."
remove_symlink "${PROJ}/graphify-out" "graphify-out"

# ── 6. Copied config files ────────────────────────────────────────────────────
step "Removing copied config files..."
remove_file "${PROJ}/.opencode/codebase-index.json" ".opencode/codebase-index.json"
remove_file "${PROJ}/repomix.config.json"            "repomix.config.json"

# ── 7. Remove graphify scheduled job for this project ─────────────────────────
step "Removing graphify scheduled job..."
if bash "${INSTALL_PATH}/graphify/schedule.sh" --remove "${PROJECT_NAME}" 2>/dev/null; then
  : # logged inside schedule.sh
else
  skip "graphify-update-${PROJECT_NAME} (not found or already removed)"
fi

# ── 8. Clean up empty parent dirs ─────────────────────────────────────────────
step "Cleaning up empty directories..."
remove_if_empty "${PROJ}/.opencode/skills"
remove_if_empty "${PROJ}/.opencode/plugins"
remove_if_empty "${PROJ}/.opencode/agents"
remove_if_empty "${PROJ}/.opencode/commands"
remove_if_empty "${PROJ}/.opencode"
remove_if_empty "${PROJ}/.ai/telamon"
remove_if_empty "${PROJ}/.ai"

# ── Done ──────────────────────────────────────────────────────────────────────
echo
log "Project '${PROJECT_NAME}' reset. Storage data preserved."
info "Re-run 'make init PROJ=${PROJ}' to re-wire the project."
echo -e "  ${TEXT_DIM}⏱  Total reset time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"

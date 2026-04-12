#!/usr/bin/env bash
# =============================================================================
# init.sh
# Initialise a project to use this ADK.
#
# Usage:
#   bin/init.sh <path/to/project>
#
# What it does:
#   1. Creates storage/<project-name>/brain/ with scaffold notes
#   2. Symlinks <project>/.ai/context/adk  → <adk-root>/src/context
#   3. Symlinks <project>/.opencode/skills/adk → <adk-root>/src/skills
#   4. Writes   <project>/.ai/adk.ini with the project name variable
#   5. Symlinks <project>/opencode.jsonc → <adk-root>/storage/opencode.jsonc
#   6. Writes   <project>/.opencode/codebase-index.json
# =============================================================================

set -euo pipefail

ADK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${ADK_ROOT}/src/install"

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

header "ADK init — ${PROJECT_NAME}"

# ── 1. Brain scaffold in storage/<project-name>/brain/ ───────────────────────
BRAIN_DIR="${ADK_ROOT}/storage/${PROJECT_NAME}/brain"
TEMPLATE_DIR="${ADK_ROOT}/src/install/obsidian"
TODAY="$(date +%Y-%m-%d)"

_write_brain_note() {
  local template="$1"
  local dest="$2"
  if [[ -f "${dest}" ]]; then
    skip "$(basename "${dest}") (already exists)"
    return
  fi
  sed \
    -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
    -e "s/DATE_PLACEHOLDER/${TODAY}/g" \
    "${TEMPLATE_DIR}/${template}" > "${dest}"
  log "Created $(basename "${dest}")"
}

step "Creating brain scaffold at storage/${PROJECT_NAME}/brain/ ..."
mkdir -p "${BRAIN_DIR}"
_write_brain_note "NorthStar.md"    "${BRAIN_DIR}/NorthStar.md"
_write_brain_note "KeyDecisions.md" "${BRAIN_DIR}/KeyDecisions.md"
_write_brain_note "Patterns.md"     "${BRAIN_DIR}/Patterns.md"
_write_brain_note "Gotchas.md"      "${BRAIN_DIR}/Gotchas.md"

# ── 2. Symlink .ai/context/adk → <adk-root>/src/context ─────────────────────
AI_CONTEXT_DIR="${PROJ}/.ai/context"
mkdir -p "${AI_CONTEXT_DIR}"

CONTEXT_LINK="${AI_CONTEXT_DIR}/adk"
if [[ -L "${CONTEXT_LINK}" ]]; then
  skip ".ai/context/adk symlink (already exists)"
else
  ln -s "${ADK_ROOT}/src/context" "${CONTEXT_LINK}"
  log "Symlinked .ai/context/adk → ${ADK_ROOT}/src/context"
fi

# ── 3. Symlink .opencode/skills/adk → <adk-root>/src/skills ─────────────────
SKILLS_DIR="${PROJ}/.opencode/skills"
mkdir -p "${SKILLS_DIR}"

SKILLS_LINK="${SKILLS_DIR}/adk"
if [[ -L "${SKILLS_LINK}" ]]; then
  skip ".opencode/skills/adk symlink (already exists)"
else
  ln -s "${ADK_ROOT}/src/skills" "${SKILLS_LINK}"
  log "Symlinked .opencode/skills/adk → ${ADK_ROOT}/src/skills"
fi

# ── 4. Write .ai/adk.ini ─────────────────────────────────────────────────────
ADK_INI="${PROJ}/.ai/adk.ini"
if [[ -f "${ADK_INI}" ]]; then
  skip ".ai/adk.ini (already exists)"
else
  mkdir -p "${PROJ}/.ai"
  cat > "${ADK_INI}" <<INI
[adk]
project_name = ${PROJECT_NAME}
INI
  log "Written .ai/adk.ini"
fi

# ── 5. opencode config: symlink or merge ─────────────────────────────────────
# Detect any existing opencode config (symlink or regular file, .jsonc or .json)
OPENCODE_TARGET="${ADK_ROOT}/storage/opencode.jsonc"
MERGE_SCRIPT="${ADK_ROOT}/src/install/opencode/merge-config.py"
OPENCODE_LINK=""      # the path we will create the symlink at (if creating)
EXISTING_FILE=""      # path to an existing regular file (if found)

for _candidate in "${PROJ}/opencode.jsonc" "${PROJ}/opencode.json"; do
  if [[ -L "${_candidate}" ]]; then
    skip "$(basename "${_candidate}") symlink (already exists)"
    OPENCODE_LINK="__skip__"
    break
  elif [[ -f "${_candidate}" ]]; then
    EXISTING_FILE="${_candidate}"
    break
  fi
done

if [[ "${OPENCODE_LINK}" != "__skip__" ]]; then
  if [[ -n "${EXISTING_FILE}" ]]; then
    # Project already has its own config — merge ADK settings into it
    if [[ ! -f "${OPENCODE_TARGET}" ]]; then
      warn "storage/opencode.jsonc not found — run 'make up' first; skipping merge"
    else
      step "Merging ADK config into $(basename "${EXISTING_FILE}") ..."
      python3 "${MERGE_SCRIPT}" "${EXISTING_FILE}" "${OPENCODE_TARGET}"
    fi
  else
    # No config exists — create symlink
    if [[ ! -f "${OPENCODE_TARGET}" ]]; then
      warn "storage/opencode.jsonc not found — run 'make up' first to create it"
    else
      ln -s "${OPENCODE_TARGET}" "${PROJ}/opencode.jsonc"
      log "Symlinked opencode.jsonc → ${OPENCODE_TARGET}"
    fi
  fi
fi

# ── 6. Write .opencode/codebase-index.json ───────────────────────────────────
step "Writing codebase-index config..."
(cd "${PROJ}" && bash "${ADK_ROOT}/src/install/codebase-index/init-project.sh")

echo
log "Project '${PROJECT_NAME}' initialised."
info "Brain notes: ${BRAIN_DIR}/"
info "Edit ${BRAIN_DIR}/NorthStar.md to set project goals."

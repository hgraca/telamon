#!/usr/bin/env bash
# =============================================================================
# init.sh
# Initialise a project to use this ADK.
#
# Usage:
#   bin/init.sh <path/to/project>
#
# What it does:
#   1. Copies src/skills/obsidian-vault/_tmpl/ → storage/obsidian/<project-name>/
#   2. Symlinks <project>/.opencode/skills/adk → <adk-root>/src/skills
#   3. Writes   <project>/.ai/adk/adk.ini with the project name variable
#   4. Symlinks <project>/.ai/adk/secrets → <adk-root>/storage/secrets
#   4b. Symlinks <project>/.ai/adk/memory → <adk-root>/storage/obsidian/<project>
#   5. Symlinks <project>/opencode.jsonc → <adk-root>/storage/opencode.jsonc
#   6. Writes   <project>/.opencode/codebase-index.json
#   7. Writes or merges AGENTS.md from src/AGENTS.md
#   8. Installs Graphify git hooks and OpenCode plugin in the project

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

# ── 1. Vault scaffold: copy _tmpl, substitute PROJECT_NAME / DATE_PLACEHOLDER ─
VAULT_ROOT="${ADK_ROOT}/storage/obsidian/${PROJECT_NAME}"
BRAIN_DIR="${VAULT_ROOT}/brain"
VAULT_TMPL="${ADK_ROOT}/src/skills/obsidian-vault/_tmpl"
TODAY="$(date +%Y-%m-%d)"

step "Creating vault at storage/obsidian/${PROJECT_NAME}/ ..."
if [[ -d "${VAULT_ROOT}" ]]; then
  skip "storage/obsidian/${PROJECT_NAME}/ (already exists)"
else
  cp -r "${VAULT_TMPL}" "${VAULT_ROOT}"
  # Substitute placeholders in every copied .md file
  find "${VAULT_ROOT}" -name "*.md" | while IFS= read -r f; do
    sed -i \
      -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
      -e "s/DATE_PLACEHOLDER/${TODAY}/g" \
      "${f}"
  done
  log "Created storage/obsidian/${PROJECT_NAME}/"
fi

# ── 2. Symlink .opencode/skills/adk → <adk-root>/src/skills ─────────────────
SKILLS_DIR="${PROJ}/.opencode/skills"
mkdir -p "${SKILLS_DIR}"

SKILLS_LINK="${SKILLS_DIR}/adk"
if [[ -L "${SKILLS_LINK}" ]]; then
  skip ".opencode/skills/adk symlink (already exists)"
else
  ln -s "${ADK_ROOT}/src/skills" "${SKILLS_LINK}"
  log "Symlinked .opencode/skills/adk → ${ADK_ROOT}/src/skills"
fi

# ── 3. Write .ai/adk/adk.ini ─────────────────────────────────────────────────
ADK_INI="${PROJ}/.ai/adk/adk.ini"
if [[ -f "${ADK_INI}" ]]; then
  skip ".ai/adk/adk.ini (already exists)"
else
  mkdir -p "${PROJ}/.ai/adk"
  cat > "${ADK_INI}" <<INI
[adk]
project_name = ${PROJECT_NAME}
INI
  log "Written .ai/adk/adk.ini"
fi

# ── 5. Symlink .ai/adk/secrets → <adk-root>/storage/secrets ─────────────────
# opencode resolves {file:.ai/adk/secrets/<name>} relative to the project root
# where opencode.jsonc lives. This symlink makes the ADK secrets visible there.
ADK_SECRETS_DIR="${PROJ}/.ai/adk"
mkdir -p "${ADK_SECRETS_DIR}"

SECRETS_LINK="${ADK_SECRETS_DIR}/secrets"
if [[ -L "${SECRETS_LINK}" ]]; then
  skip ".ai/adk/secrets symlink (already exists)"
else
  ln -s "${ADK_ROOT}/storage/secrets" "${SECRETS_LINK}"
  log "Symlinked .ai/adk/secrets → ${ADK_ROOT}/storage/secrets"
fi

# ── 5b. Symlink .ai/adk/memory → <adk-root>/storage/obsidian/<project> ────────
MEMORY_LINK="${ADK_SECRETS_DIR}/memory"
if [[ -L "${MEMORY_LINK}" ]]; then
  skip ".ai/adk/memory symlink (already exists)"
else
  ln -s "${VAULT_ROOT}" "${MEMORY_LINK}"
  log "Symlinked .ai/adk/memory → ${VAULT_ROOT}"
fi

# ── 6. opencode config: symlink or merge ─────────────────────────────────────
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

# ── 7. Write .opencode/codebase-index.json ───────────────────────────────────
step "Writing codebase-index config..."
(cd "${PROJ}" && bash "${ADK_ROOT}/src/install/codebase-index/init-project.sh")

# ── 8. Write or merge AGENTS.md ──────────────────────────────────────────────
# If the project has no AGENTS.md, copy ours. If it does, append any lines from
# src/AGENTS.md that are not already present (line-by-line dedup).
ADK_AGENTS_SRC="${ADK_ROOT}/src/AGENTS.md"
PROJ_AGENTS="${PROJ}/AGENTS.md"

step "Configuring AGENTS.md..."
if [[ ! -f "${PROJ_AGENTS}" ]]; then
  cp "${ADK_AGENTS_SRC}" "${PROJ_AGENTS}"
  log "Created AGENTS.md"
else
  ADDED=0
  while IFS= read -r line; do
    if ! grep -qF "${line}" "${PROJ_AGENTS}"; then
      echo "${line}" >> "${PROJ_AGENTS}"
      ADDED=$((ADDED + 1))
    fi
  done < "${ADK_AGENTS_SRC}"
  if [[ "${ADDED}" -gt 0 ]]; then
    log "Merged ${ADDED} line(s) into existing AGENTS.md"
  else
    skip "AGENTS.md (all ADK lines already present)"
  fi
fi

# ── 9. Graphify git hooks + OpenCode plugin ───────────────────────────────────
(cd "${PROJ}" && INSTALL_PATH="${ADK_ROOT}/src/install" bash "${ADK_ROOT}/src/install/graphify/init-project.sh")

echo
log "Project '${PROJECT_NAME}' initialised."
info "Brain notes: ${BRAIN_DIR}/"
info "Edit ${BRAIN_DIR}/NorthStar.md to set project goals."

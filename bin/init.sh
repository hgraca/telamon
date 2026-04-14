#!/usr/bin/env bash
# =============================================================================
# init.sh
# Initialise a project to use this ADK.
#
# Usage:
#   bin/init.sh <path/to/project>
#
# What it does:
#   1. Builds storage/obsidian/<project-name>/ by:
#        - mirroring the _tmpl/ folder structure (real dirs)
#        - symlinking every file that has no placeholders → _tmpl/<rel-path>
#        - copying + substituting every file that contains PROJECT_NAME /
#          DATE_PLACEHOLDER (currently the four brain/*.md files)
#      Then symlinks <project>/.ai/adk/memory → storage/obsidian/<project-name>
#   2. Symlinks <project>/.opencode/skills/adk → <adk-root>/src/skills
#   3. Writes   <project>/.ai/adk/adk.ini with the project name variable
#   4. Symlinks <project>/.ai/adk/secrets → <adk-root>/storage/secrets
#   5. Symlinks <project>/opencode.jsonc → <adk-root>/storage/opencode.jsonc
#   6. Writes   <project>/.opencode/codebase-index.json
#   7. Writes or merges AGENTS.md from src/AGENTS.md
#   8. Installs Graphify git hooks and OpenCode plugin in the project
#   9. Installs session-capture OpenCode plugin in the project
#  10. Installs cass post-commit git hook in the project

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

# ── 1. Vault scaffold ─────────────────────────────────────────────────────────
# Layout:
#   storage/obsidian/<proj>/   — mirrored dir tree; files are symlinks → _tmpl
#                                except the 4 brain files which are real copies
#                                (they contain PROJECT_NAME / DATE_PLACEHOLDER
#                                substitutions so they cannot be symlinks)
#   <proj>/.ai/adk/memory      — symlink → storage/obsidian/<proj>
VAULT_ROOT="${ADK_ROOT}/storage/obsidian/${PROJECT_NAME}"
VAULT_TMPL="${ADK_ROOT}/src/skills/memory/obsidian-vault/_tmpl"
MEMORY_LINK="${PROJ}/.ai/adk/memory"
BRAIN_DIR="${VAULT_ROOT}/brain"
TODAY="$(date +%Y-%m-%d)"

step "Building vault at storage/obsidian/${PROJECT_NAME}/ ..."
if [[ -d "${VAULT_ROOT}" ]]; then
  skip "storage/obsidian/${PROJECT_NAME}/ (already exists)"
else
  mkdir -p "${ADK_ROOT}/storage/obsidian"

  # Walk the template tree: create real dirs, symlink or copy each file
  while IFS= read -r tmpl_file; do
    rel="${tmpl_file#"${VAULT_TMPL}/"}"          # e.g. brain/memories.md
    dest="${VAULT_ROOT}/${rel}"
    dest_dir="$(dirname "${dest}")"

    mkdir -p "${dest_dir}"

    if [[ "$(basename "${tmpl_file}")" == ".gitkeep" ]]; then
      # Directory placeholder — the dir was already created by mkdir -p; skip
      continue
    elif grep -q "PROJECT_NAME\|DATE_PLACEHOLDER" "${tmpl_file}" 2>/dev/null; then
      # File has placeholders → real copy with substitution
      cp "${tmpl_file}" "${dest}"
      sed -i \
        -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
        -e "s/DATE_PLACEHOLDER/${TODAY}/g" \
        "${dest}"
    else
      # No placeholders → symlink to the template source
      ln -s "${tmpl_file}" "${dest}"
    fi
  done < <(find "${VAULT_TMPL}" -type f | sort)

  log "Built storage/obsidian/${PROJECT_NAME}/"
fi

# Symlink <proj>/.ai/adk/memory → storage/obsidian/<proj>
step "Symlinking .ai/adk/memory → storage/obsidian/${PROJECT_NAME} ..."
if [[ -L "${MEMORY_LINK}" ]]; then
  skip ".ai/adk/memory symlink (already exists)"
elif [[ -d "${MEMORY_LINK}" ]]; then
  warn ".ai/adk/memory is a real directory — skipping symlink creation"
else
  mkdir -p "${PROJ}/.ai/adk"
  ln -s "${VAULT_ROOT}" "${MEMORY_LINK}"
  log "Symlinked .ai/adk/memory → ${VAULT_ROOT}"
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

# ── 5b. .ai/adk/memory is the real vault dir (created in step 1) ─────────────
# No symlink needed here — the real files live at <proj>/.ai/adk/memory/.
# The reverse symlink (storage/obsidian/<proj> → <proj>/.ai/adk/memory) is
# created in step 1 above.

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

# ── 10. Session-capture OpenCode plugin ──────────────────────────────────────
(cd "${PROJ}" && INSTALL_PATH="${ADK_ROOT}/src/install" bash "${ADK_ROOT}/src/install/session-capture/init-project.sh")

# ── 11. cass post-commit git hook ────────────────────────────────────────────
(cd "${PROJ}" && INSTALL_PATH="${ADK_ROOT}/src/install" bash "${ADK_ROOT}/src/install/cass/init-project.sh")

echo
log "Project '${PROJECT_NAME}' initialised."
info "Memory notes: ${BRAIN_DIR}/"
info "Edit ${BRAIN_DIR}/memories.md to record project lessons."

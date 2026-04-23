#!/usr/bin/env bash
# Wire up a project to use Telamon's opencode configuration.
#
# Steps:
#   1. Symlink .opencode/skills/telamon → <telamon-root>/src/skills
#   2. Symlink .opencode/plugins/telamon → <telamon-root>/src/plugins
#   3. Symlink .opencode/agents/telamon → <telamon-root>/src/agents
#   4. Symlink .opencode/commands/telamon → <telamon-root>/src/commands
#   5. Write   .ai/telamon/telamon.ini with the project name
#   6. Symlink .ai/telamon/secrets → <telamon-root>/storage/secrets
#   7. Symlink .ai/telamon/scripts → <telamon-root>/scripts
#   8. Symlink opencode.jsonc → <telamon-root>/storage/opencode.jsonc
#      (or merge Telamon settings into an existing project config)
#   9. AGENTS.md — copy dist to storage, symlink from project root
#
# Expected environment (exported by bin/init.sh):
#   PROJ          — absolute path to the project root
#   PROJECT_NAME  — basename of the project
#   TELAMON_ROOT      — absolute path to Telamon repository
#   INSTALL_PATH  — absolute path to src/install/

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# Resolve project context — prefer exported vars, fall back to PWD
PROJ="${PROJ:-$(pwd)}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "${PROJ}")}"

header "opencode"

# ── 1. Symlink .opencode/skills/telamon → <telamon-root>/src/skills ─────────────────
SKILLS_DIR="${PROJ}/.opencode/skills"
mkdir -p "${SKILLS_DIR}"
SKILLS_LINK="${SKILLS_DIR}/telamon"
if [[ -L "${SKILLS_LINK}" ]]; then
  skip ".opencode/skills/telamon symlink (already exists)"
else
  ln -s "${TELAMON_ROOT}/src/skills" "${SKILLS_LINK}"
  log "Symlinked .opencode/skills/telamon → ${TELAMON_ROOT}/src/skills"
fi

# ── 2. Symlink .opencode/plugins/telamon → <telamon-root>/src/plugins ───────────────
PLUGINS_DIR="${PROJ}/.opencode/plugins"
mkdir -p "${PLUGINS_DIR}"
PLUGINS_LINK="${PLUGINS_DIR}/telamon"
if [[ -L "${PLUGINS_LINK}" ]]; then
  skip ".opencode/plugins/telamon symlink (already exists)"
else
  ln -s "${TELAMON_ROOT}/src/plugins" "${PLUGINS_LINK}"
  log "Symlinked .opencode/plugins/telamon → ${TELAMON_ROOT}/src/plugins"
fi

# ── 3. Symlink .opencode/agents/telamon → <telamon-root>/src/agents ─────────────────
AGENTS_DIR="${PROJ}/.opencode/agents"
mkdir -p "${AGENTS_DIR}"
AGENTS_LINK="${AGENTS_DIR}/telamon"
if [[ -L "${AGENTS_LINK}" ]]; then
  skip ".opencode/agents/telamon symlink (already exists)"
else
  ln -s "${TELAMON_ROOT}/src/agents" "${AGENTS_LINK}"
  log "Symlinked .opencode/agents/telamon → ${TELAMON_ROOT}/src/agents"
fi

# ── 4. Symlink .opencode/commands/telamon → <telamon-root>/src/commands ─────────────
COMMANDS_DIR="${PROJ}/.opencode/commands"
mkdir -p "${COMMANDS_DIR}"
COMMANDS_LINK="${COMMANDS_DIR}/telamon"
if [[ -L "${COMMANDS_LINK}" ]]; then
  skip ".opencode/commands/telamon symlink (already exists)"
else
  ln -s "${TELAMON_ROOT}/src/commands" "${COMMANDS_LINK}"
  log "Symlinked .opencode/commands/telamon → ${TELAMON_ROOT}/src/commands"
fi

# ── 5. Write .ai/telamon/telamon.ini ─────────────────────────────────────────────────
TELAMON_INI="${PROJ}/.ai/telamon/telamon.ini"
if [[ -f "${TELAMON_INI}" ]]; then
  skip ".ai/telamon/telamon.ini (already exists)"
else
  mkdir -p "${PROJ}/.ai/telamon"
  cat > "${TELAMON_INI}" <<INI
[telamon]
project_name = ${PROJECT_NAME}
rtk_enabled = false
caveman_enabled = false
medium_model =
INI
  log "Written .ai/telamon/telamon.ini"
fi

# ── 6. Symlink .ai/telamon/secrets → <telamon-root>/storage/secrets ─────────────────
# opencode resolves {file:.ai/telamon/secrets/<name>} relative to the project root
# where opencode.jsonc lives. This symlink makes Telamon secrets visible there.
TELAMON_SECRETS_DIR="${PROJ}/.ai/telamon"
mkdir -p "${TELAMON_SECRETS_DIR}"
SECRETS_LINK="${TELAMON_SECRETS_DIR}/secrets"
if [[ -L "${SECRETS_LINK}" ]]; then
  skip ".ai/telamon/secrets symlink (already exists)"
else
  ln -s "${TELAMON_ROOT}/storage/secrets" "${SECRETS_LINK}"
  log "Symlinked .ai/telamon/secrets → ${TELAMON_ROOT}/storage/secrets"
fi

# ── 7. Symlink .ai/telamon/scripts → <telamon-root>/scripts ─────────────────────
SCRIPTS_LINK="${PROJ}/.ai/telamon/scripts"
if [[ -L "${SCRIPTS_LINK}" ]]; then
  skip ".ai/telamon/scripts symlink (already exists)"
else
  mkdir -p "${PROJ}/.ai/telamon"
  ln -s "${TELAMON_ROOT}/scripts" "${SCRIPTS_LINK}"
  log "Symlinked .ai/telamon/scripts → ${TELAMON_ROOT}/scripts"
fi

# ── 8. opencode config: symlink or merge ─────────────────────────────────────
# Detect any existing opencode config (symlink or regular file, .jsonc or .json)
OPENCODE_TARGET="${TELAMON_ROOT}/storage/opencode.jsonc"
MERGE_SCRIPT="${TELAMON_ROOT}/src/install/opencode/merge-config.py"
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
    # Project already has its own config — merge Telamon settings into it
    if [[ ! -f "${OPENCODE_TARGET}" ]]; then
      warn "storage/opencode.jsonc not found — run 'make up' first; skipping merge"
    else
      step "Merging Telamon config into $(basename "${EXISTING_FILE}") ..."
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

# ── 9. AGENTS.md — copy dist to storage, symlink from project root ───────────
TELAMON_AGENTS_SRC="${TELAMON_ROOT}/src/AGENTS.dist.md"
AGENTS_STORAGE="${TELAMON_ROOT}/storage/AGENTS.shared.md"
PROJ_AGENTS="${PROJ}/AGENTS.md"

step "Configuring AGENTS.md..."
if [[ -L "${PROJ_AGENTS}" ]]; then
  skip "AGENTS.md symlink (already exists)"
elif [[ -f "${PROJ_AGENTS}" ]]; then
  # Project has its own AGENTS.md — move to storage, symlink, then merge dist lines
  cp "${PROJ_AGENTS}" "${AGENTS_STORAGE}"
  rm "${PROJ_AGENTS}"
  ln -s "${AGENTS_STORAGE}" "${PROJ_AGENTS}"
  ADDED=0
  while IFS= read -r line; do
    if ! grep -qF "${line}" "${AGENTS_STORAGE}"; then
      echo "${line}" >> "${AGENTS_STORAGE}"
      ADDED=$((ADDED + 1))
    fi
  done < "${TELAMON_AGENTS_SRC}"
  log "Moved existing AGENTS.md to storage and symlinked"
else
  # Nothing exists — copy dist to storage (preserve if re-running), then symlink
  if [[ ! -f "${AGENTS_STORAGE}" ]]; then
    cp "${TELAMON_AGENTS_SRC}" "${AGENTS_STORAGE}"
  fi
  ln -s "${AGENTS_STORAGE}" "${PROJ_AGENTS}"
  log "Created AGENTS.md (storage/AGENTS.shared.md)"
fi

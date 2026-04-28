#!/usr/bin/env bash
# Wire up a project to use Telamon's opencode configuration.
#
# Steps:
#   1. Symlink .opencode/skills/telamon → <telamon-root>/src/skills
#   2. Symlink .opencode/plugins/telamon → <telamon-root>/src/plugins
#   3. Symlink .opencode/agents/telamon → <telamon-root>/src/agents
#   4. Symlink .opencode/commands/telamon → <telamon-root>/src/commands
#   5. Symlink .opencode/scripts/telamon → <telamon-root>/scripts
#   6. Write   .ai/telamon/telamon.jsonc with the project name
#   7. Symlink .ai/telamon/secrets → <telamon-root>/storage/secrets
#   8. Symlink .ai/telamon/scripts → <telamon-root>/scripts
#   9. Symlink opencode.jsonc → <telamon-root>/storage/opencode.jsonc
#      (or merge Telamon settings into an existing project config)
#  10. AGENTS.md — copy dist to storage, symlink from project root
#
# Expected environment (exported by bin/init.sh):
#   PROJ          — absolute path to the project root
#   PROJECT_NAME  — basename of the project
#   TELAMON_ROOT      — absolute path to Telamon repository
#   TOOLS_PATH  — absolute path to src/tools/

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

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

# ── 5. Symlink .opencode/scripts/telamon → <telamon-root>/scripts ────────────────────
SCRIPTS_OC_DIR="${PROJ}/.opencode/scripts"
mkdir -p "${SCRIPTS_OC_DIR}"
SCRIPTS_OC_LINK="${SCRIPTS_OC_DIR}/telamon"
if [[ -L "${SCRIPTS_OC_LINK}" ]]; then
  skip ".opencode/scripts/telamon symlink (already exists)"
else
  ln -s "${TELAMON_ROOT}/scripts" "${SCRIPTS_OC_LINK}"
  log "Symlinked .opencode/scripts/telamon → ${TELAMON_ROOT}/scripts"
fi

# ── 6. Write .ai/telamon/telamon.jsonc ────────────────────────────────────────────────
TELAMON_CFG="${PROJ}/.ai/telamon/telamon.jsonc"

# Migrate old INI format if present
if [[ -f "${PROJ}/.ai/telamon/telamon.ini" && ! -f "${TELAMON_CFG}" ]]; then
  step "Migrating telamon.ini → telamon.jsonc ..."
  python3 - "${PROJ}/.ai/telamon/telamon.ini" "${TELAMON_CFG}" <<'PYEOF'
import re, json, sys

ini_path = sys.argv[1]
out_path = sys.argv[2]
data = {}
with open(ini_path) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('[') or line.startswith('#') or line.startswith(';'):
            continue
        if '=' in line:
            k, v = line.split('=', 1)
            k = k.strip()
            v = v.strip()
            if v.lower() == 'true':
                data[k] = True
            elif v.lower() == 'false':
                data[k] = False
            else:
                data[k] = v

with open(out_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
  rm "${PROJ}/.ai/telamon/telamon.ini"
  log "Migrated telamon.ini → telamon.jsonc"
fi

if [[ -f "${TELAMON_CFG}" ]]; then
  skip ".ai/telamon/telamon.jsonc (already exists)"
  # Ensure new keys are present (migration for older configs)
  python3 - "${TELAMON_CFG}" "${MEMORY_OWNER:-telamon}" "${OGHAM_DB:-telamon}" <<'PYEOF'
import json, re, sys

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

path = sys.argv[1]
memory_owner = sys.argv[2]
ogham_db = sys.argv[3]
changed = False

with open(path) as f:
    data = json.loads(strip(f.read()))

if 'memory_owner' not in data:
    data['memory_owner'] = memory_owner
    changed = True
if 'ogham_db' not in data:
    data['ogham_db'] = ogham_db
    changed = True

if changed:
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
PYEOF
else
  mkdir -p "${PROJ}/.ai/telamon"
  cat > "${TELAMON_CFG}" <<JSONEOF
{
  "project_name": "${PROJECT_NAME}",
  "rtk_enabled": false,
  "caveman_enabled": false,
  "medium_model": "",
  "memory_owner": "${MEMORY_OWNER:-telamon}",
  "ogham_db": "${OGHAM_DB:-telamon}"
}
JSONEOF
  log "Written .ai/telamon/telamon.jsonc"
fi

# ── 6. Create .ai/telamon/secrets/ real directory with individual symlinks ────
# opencode resolves {file:.ai/telamon/secrets/<name>} relative to the project root
# where opencode.jsonc lives. Individual symlinks make Telamon secrets visible there,
# while allowing per-project overrides (e.g. ogham-database-url for external DB).
SECRETS_DIR="${PROJ}/.ai/telamon/secrets"

# Handle migration: if secrets is an old-style directory symlink, replace it
if [[ -L "${SECRETS_DIR}" ]]; then
  rm "${SECRETS_DIR}"
  mkdir -p "${SECRETS_DIR}"
  log "Migrated .ai/telamon/secrets from directory symlink to per-project directory"
else
  mkdir -p "${SECRETS_DIR}"
fi

# Symlink each global secret into the per-project directory
for _secret_file in "${TELAMON_ROOT}/storage/secrets"/*; do
  [[ -f "${_secret_file}" ]] || continue
  _secret_name="$(basename "${_secret_file}")"
  _secret_link="${SECRETS_DIR}/${_secret_name}"

  if [[ -e "${_secret_link}" || -L "${_secret_link}" ]]; then
    skip "secret: ${_secret_name} (already exists)"
  else
    ln -s "${_secret_file}" "${_secret_link}"
    log "Linked secret: ${_secret_name}"
  fi
done

# ── 6b. Handle ogham-database-url based on OGHAM_DB mode ─────────────────────
if [[ "${OGHAM_DB:-telamon}" == "external" && -n "${OGHAM_DB_URL:-}" ]]; then
  _ogham_secret="${SECRETS_DIR}/ogham-database-url"
  # Remove existing symlink if present
  [[ -L "${_ogham_secret}" ]] && rm "${_ogham_secret}"
  printf '%s' "${OGHAM_DB_URL}" > "${_ogham_secret}"
  chmod 600 "${_ogham_secret}"
  log "Wrote project-specific ogham-database-url (external DB)"
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
MERGE_SCRIPT="${TELAMON_ROOT}/src/tools/opencode/merge-config.py"
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

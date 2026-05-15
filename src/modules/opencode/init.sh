#!/usr/bin/env bash
# Wire up a project to use Telamon's opencode configuration.
#
# Steps:
#   1. Symlink .opencode/skills/telamon → <telamon-root>/src/instructions/skills
#   2. Symlink .opencode/plugins/telamon → <telamon-root>/src/instructions/plugins
#   3. Symlink .opencode/agents/telamon → <telamon-root>/src/instructions/agents
#   4. Symlink .opencode/commands/telamon → <telamon-root>/src/instructions/commands
#   5. Per-file flat symlinks .opencode/tools/<name>.ts → <telamon-root>/src/instructions/tools/<name>/<name>.ts
#   6. Write   .ai/telamon/telamon.jsonc with the project name
#   7. Symlink .ai/telamon/secrets → <telamon-root>/storage/secrets
#   8. Symlink opencode.jsonc → <telamon-root>/storage/opencode.jsonc
#      (or merge Telamon settings into an existing project config)
#   9. AGENTS.md — copy dist to storage, symlink from project root
#
# Expected environment (exported by bin/init.sh):
#   PROJ          — absolute path to the project root
#   PROJECT_NAME  — basename of the project
#   TELAMON_ROOT      — absolute path to Telamon repository
#   TOOLS_PATH  — absolute path to src/modules/ (parent dir of this tool)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# Resolve project context — prefer exported vars, fall back to PWD
PROJ="${PROJ:-$(pwd)}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "${PROJ}")}"

header "opencode"

# ── 1. Symlink .opencode/skills/telamon → <telamon-root>/src/instructions/skills ─────────────────
SKILLS_DIR="${PROJ}/.opencode/skills"
mkdir -p "${SKILLS_DIR}"
SKILLS_LINK="${SKILLS_DIR}/telamon"
ensure_symlink "${SKILLS_LINK}" "${TELAMON_ROOT}/src/instructions/skills" ".opencode/skills/telamon"

# ── 2. Symlink .opencode/plugins/telamon → <telamon-root>/src/instructions/plugins ───────────────
PLUGINS_DIR="${PROJ}/.opencode/plugins"
mkdir -p "${PLUGINS_DIR}"
PLUGINS_LINK="${PLUGINS_DIR}/telamon"
ensure_symlink "${PLUGINS_LINK}" "${TELAMON_ROOT}/src/instructions/plugins" ".opencode/plugins/telamon"

# ── 3. Symlink .opencode/agents/telamon → <telamon-root>/src/instructions/agents ─────────────────
AGENTS_DIR="${PROJ}/.opencode/agents"
mkdir -p "${AGENTS_DIR}"
AGENTS_LINK="${AGENTS_DIR}/telamon"
ensure_symlink "${AGENTS_LINK}" "${TELAMON_ROOT}/src/instructions/agents" ".opencode/agents/telamon"

# ── 4. Symlink .opencode/commands/telamon → <telamon-root>/src/instructions/commands ─────────────
COMMANDS_DIR="${PROJ}/.opencode/commands"
mkdir -p "${COMMANDS_DIR}"
COMMANDS_LINK="${COMMANDS_DIR}/telamon"
ensure_symlink "${COMMANDS_LINK}" "${TELAMON_ROOT}/src/instructions/commands" ".opencode/commands/telamon"

# ── 5. Per-file flat symlinks .opencode/tools/<name>.ts → src/instructions/tools/<name>/<name>.ts ─
# Custom tools have two strict location requirements (see latent/gotchas.md
# "Opencode custom tools require flat layout AND co-located node_modules"):
#
#   1. Tool .ts files must be discovered as flat files directly under
#      .opencode/tools/ — opencode does NOT walk into nested subdirs (so the
#      .opencode/tools/telamon/ → src/instructions/tools/ dir-symlink convention
#      that works for skills/plugins/agents/commands does NOT carry over here).
#
#   2. The `import { tool } from "@opencode-ai/plugin"` resolves relative to the
#      file's REAL path. Bun walks up from the symlink target. We therefore
#      install @opencode-ai/plugin once at src/instructions/tools/node_modules/
#      so every tool .ts file under that tree can resolve the package without
#      duplication. That install runs in opencode/install.sh and opencode/update.sh
#      (telamon-checkout-scoped, not per-project) — this step assumes it has run.
#
# Layout convention: src/instructions/tools/<name>/<name>.ts (+ optional sibling
# script). The flat symlink at .opencode/tools/<name>.ts resolves to that file.

TOOLS_SRC="${TELAMON_ROOT}/src/instructions/tools"
TOOLS_DIR="${PROJ}/.opencode/tools"
mkdir -p "${TOOLS_DIR}"

# Warn if the telamon-scoped install never ran — tools will fail to register.
if [[ -f "${TOOLS_SRC}/package.json" && ! -d "${TOOLS_SRC}/node_modules/@opencode-ai/plugin" ]]; then
  warn "${TOOLS_SRC}/node_modules/@opencode-ai/plugin is missing — run \`make install\` or \`make update\` to install tool dependencies. Custom tools will not load until then."
fi

# Symlink each src/instructions/tools/<name>/<name>.ts as a flat file.
_tools_linked=0
if [[ -d "${TOOLS_SRC}" ]]; then
  for _tool_dir in "${TOOLS_SRC}"/*/; do
    [[ -d "${_tool_dir}" ]] || continue
    _tool_name="$(basename "${_tool_dir}")"
    _tool_src="${_tool_dir}${_tool_name}.ts"
    [[ -f "${_tool_src}" ]] || continue
    _tool_link="${TOOLS_DIR}/${_tool_name}.ts"
    ensure_symlink "${_tool_link}" "${_tool_src}" ".opencode/tools/${_tool_name}.ts"
    [[ -L "${_tool_link}" ]] && _tools_linked=$((_tools_linked + 1))
  done
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
  python3 - "${FUNCTIONS_PATH}" "${TELAMON_CFG}" "${MEMORY_OWNER:-telamon}" "${OGHAM_DB:-telamon}" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[1])
from strip_jsonc import load_jsonc

path = sys.argv[2]
memory_owner = sys.argv[3]
ogham_db = sys.argv[4]
changed = False

with open(path) as f:
    data = load_jsonc(f.read())

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
  "rtk_enabled": true,
  "caveman_enabled": true,
  "medium_model": "",
  "memory_owner": "${MEMORY_OWNER:-telamon}",
  "ogham_db": "${OGHAM_DB:-telamon}",
  "agent_communication": {
    "enabled": true,
    "max_attempts": 2,
    "exempt_agents": ["repomix-agent", "qmd"]
  }
}
JSONEOF
  log "Written .ai/telamon/telamon.jsonc"
fi

# ── 6. Create .ai/telamon/secrets/ real directory with individual symlinks ───────
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

# ── 7. opencode config: symlink or merge ─────────────────────────────────────
# Detect any existing opencode config (symlink or regular file, .jsonc or .json)
OPENCODE_TARGET="${TELAMON_ROOT}/storage/opencode.jsonc"
MERGE_SCRIPT="${TELAMON_ROOT}/src/modules/opencode/merge-config.py"
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
      warn "storage/opencode.jsonc not found — run 'make install' first; skipping merge"
    else
      step "Merging Telamon config into $(basename "${EXISTING_FILE}") ..."
      python3 "${MERGE_SCRIPT}" "${EXISTING_FILE}" "${OPENCODE_TARGET}"
    fi
  else
    # No config exists — create symlink
    if [[ ! -f "${OPENCODE_TARGET}" ]]; then
      warn "storage/opencode.jsonc not found — run 'make install' first to create it"
    else
      ln -s "${OPENCODE_TARGET}" "${PROJ}/opencode.jsonc"
      log "Symlinked opencode.jsonc → ${OPENCODE_TARGET}"
    fi
  fi
fi

# ── 8. AGENTS.md — copy dist to storage, symlink from project root ───────────
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

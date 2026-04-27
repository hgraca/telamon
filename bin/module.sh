#!/usr/bin/env bash
# =============================================================================
# bin/module.sh
# Manage external module repos — clone, wire symlinks into projects.
#
# Usage:
#   telamon module add <url> [--commands=<path>] [--agents=<path>] [--skills=<path>] [--plugins=<path>]
#   telamon module remove <name>   # name is org/repo
#   telamon module list
#   telamon module sync            # re-wire all modules to all projects
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${TELAMON_ROOT}/src/install"
export INSTALL_PATH TELAMON_ROOT

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

MODULES_FILE="${TELAMON_ROOT}/.telamon.jsonc"

# ── Helpers ───────────────────────────────────────────────────────────────────

# _derive_path <url>
# Converts a git URL to a vendor/<org>/<repo> path.
# Handles HTTPS:  https://github.com/org/repo.git
# Handles SSH:    git@github.com:org/repo.git
_derive_path() {
  local url="${1%/}"
  url="${url%.git}"

  local org_repo
  if [[ "${url}" == git@* ]]; then
    org_repo="${url##*:}"
  else
    local path_part="${url#*://}"
    path_part="${path_part#*/}"
    local repo; repo="$(basename "${path_part}")"
    local org;  org="$(basename "$(dirname "${path_part}")")"
    org_repo="${org}/${repo}"
  fi

  echo "vendor/${org_repo}"
}

# _url_to_name <url>
# Extracts org/repo from a URL (without .git suffix).
_url_to_name() {
  local url="${1%/}"
  url="${url%.git}"

  if [[ "${url}" == git@* ]]; then
    echo "${url##*:}"
  else
    local path_part="${url#*://}"
    path_part="${path_part#*/}"
    local repo; repo="$(basename "${path_part}")"
    local org;  org="$(basename "$(dirname "${path_part}")")"
    echo "${org}/${repo}"
  fi
}

# _ensure_modules_file
# Ensures .telamon.jsonc exists with a modules section. Migrates from legacy sources.
_ensure_modules_file() {
  if [[ ! -f "${MODULES_FILE}" ]]; then
    if [[ -f "${TELAMON_ROOT}/.telamon.dist.jsonc" ]]; then
      cp "${TELAMON_ROOT}/.telamon.dist.jsonc" "${MODULES_FILE}"
      log "Created .telamon.jsonc from .telamon.dist.jsonc"
    else
      cat > "${MODULES_FILE}" <<'JSONC'
{
  "modules": {
    "addyosmani/agent-skills": {
      "url": "https://github.com/addyosmani/agent-skills.git",
      "paths": {
        "skills": "."
      },
      "builtin": true
    }
  }
}
JSONC
      log "Created .telamon.jsonc with built-in addyosmani/agent-skills"
    fi
  fi

  # Ensure "modules" key exists
  python3 - "${MODULES_FILE}" <<'PYEOF'
import json, re, sys

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

path = sys.argv[1]
with open(path) as f:
    data = json.loads(strip(f.read()))

if 'modules' not in data:
    data['modules'] = {
        "addyosmani/agent-skills": {
            "url": "https://github.com/addyosmani/agent-skills.git",
            "paths": {"skills": "."},
            "builtin": True
        }
    }
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
PYEOF

  # Migrate from storage/modules.jsonc if present (legacy)
  local _legacy="${TELAMON_ROOT}/storage/modules.jsonc"
  if [[ -f "${_legacy}" ]]; then
    step "Migrating storage/modules.jsonc → .telamon.jsonc ..."
    python3 - "${_legacy}" "${MODULES_FILE}" <<'PYEOF'
import json, re, sys

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

legacy_path = sys.argv[1]
target_path = sys.argv[2]

with open(legacy_path) as f:
    legacy = json.loads(strip(f.read()))

with open(target_path) as f:
    data = json.loads(strip(f.read()))

modules = data.get('modules', {})
for name, entry in legacy.items():
    if name not in modules:
        modules[name] = entry

data['modules'] = modules
with open(target_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
    rm "${_legacy}"
    log "Migrated storage/modules.jsonc → .telamon.jsonc"
  fi

  # Migrate TELAMON_SUBMODULES from .env if present
  local env_file="${TELAMON_ROOT}/.env"
  if [[ -f "${env_file}" ]]; then
    local raw
    raw="$(grep -s '^TELAMON_SUBMODULES=' "${env_file}" | head -1 | cut -d= -f2- | tr -d "\"'" || true)"
    if [[ -n "${raw}" ]]; then
      step "Migrating TELAMON_SUBMODULES from .env ..."
      IFS=',' read -ra _migrate_urls <<< "${raw}"
      for _murl in "${_migrate_urls[@]}"; do
        _murl="${_murl// /}"
        [[ -z "${_murl}" ]] && continue
        local _mname
        _mname="$(_url_to_name "${_murl}")"
        # Skip if it's the built-in
        [[ "${_mname}" == "addyosmani/agent-skills" ]] && continue
        # Add to .telamon.jsonc modules section
        python3 - "${MODULES_FILE}" "${_mname}" "${_murl}" <<'PYEOF'
import json, sys, re

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

path = sys.argv[1]
name = sys.argv[2]
url  = sys.argv[3]

with open(path) as f:
    data = json.loads(strip(f.read()))

modules = data.get('modules', {})
if name not in modules:
    modules[name] = {
        "url": url,
        "paths": {
            "commands": "./commands",
            "agents":   "./agents",
            "skills":   "./skills",
            "plugins":  "./plugins"
        }
    }
data['modules'] = modules

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
        log "Migrated: ${_mname} (${_murl})"
      done

      # Remove TELAMON_SUBMODULES from .env
      sed -i.bak '/^TELAMON_SUBMODULES=/d' "${env_file}"
      rm -f "${env_file}.bak"
      log "Removed TELAMON_SUBMODULES from .env"
    fi
  fi
}

# _read_modules_jsonc
# Outputs the "modules" section as parsed JSON (comments stripped) to stdout.
_read_modules_jsonc() {
  python3 - "${MODULES_FILE}" <<'PYEOF'
import json, sys, re

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

with open(sys.argv[1]) as f:
    data = json.loads(strip(f.read()))

print(json.dumps(data.get('modules', {})))
PYEOF
}

# _get_module_field <name> <field>
# Reads a top-level field from a module entry in the "modules" section.
# Returns empty string if missing.
_get_module_field() {
  local name="$1" field="$2"
  python3 - "${MODULES_FILE}" "${name}" "${field}" <<'PYEOF'
import json, sys, re

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

with open(sys.argv[1]) as f:
    data = json.loads(strip(f.read()))

name  = sys.argv[2]
field = sys.argv[3]

modules = data.get('modules', {})
entry   = modules.get(name, {})
val     = entry.get(field, '')
if isinstance(val, bool):
    print('true' if val else 'false')
elif isinstance(val, dict):
    print(json.dumps(val))
else:
    print(val)
PYEOF
}

# _wire_module_to_project <name> <vendor_dir> <paths_json> <project_dir>
# Creates symlinks for one module in one project.
_wire_module_to_project() {
  local name="$1"
  local vendor_dir="$2"
  local paths_json="$3"
  local project_dir="$4"

  # Derive symlink name: org/repo → org-repo
  local link_name="${name//\//-}"

  # For each type, check if the path exists in vendor and create symlink
  for type in skills plugins agents commands; do
    local rel_path
    rel_path="$(python3 -c "
import json, sys
paths = json.loads(sys.argv[1])
print(paths.get(sys.argv[2], ''))
" "${paths_json}" "${type}")"

    [[ -z "${rel_path}" ]] && continue

    # Resolve the actual source directory
    local src_dir
    src_dir="$(cd "${vendor_dir}" && cd "${rel_path}" 2>/dev/null && pwd)" || continue
    [[ -d "${src_dir}" ]] || continue

    local target_dir="${project_dir}/.opencode/${type}"
    local link_path="${target_dir}/${link_name}"

    mkdir -p "${target_dir}"

    if [[ -L "${link_path}" ]]; then
      skip ".opencode/${type}/${link_name} symlink (already exists)"
    elif [[ -e "${link_path}" ]]; then
      warn ".opencode/${type}/${link_name} exists but is not a symlink — skipping"
    else
      ln -s "${src_dir}" "${link_path}"
      log "Symlinked .opencode/${type}/${link_name} → ${src_dir}"
    fi
  done
}

# _remove_module_wiring <name> <project_dir>
# Removes symlinks for one module from one project.
_remove_module_wiring() {
  local name="$1"
  local project_dir="$2"
  local link_name="${name//\//-}"

  for type in skills plugins agents commands; do
    local link_path="${project_dir}/.opencode/${type}/${link_name}"
    if [[ -L "${link_path}" ]]; then
      rm "${link_path}"
      log "Removed .opencode/${type}/${link_name}"
    fi
  done
}

# _discover_projects
# Prints absolute paths of all initialized projects, one per line.
_discover_projects() {
  while IFS= read -r _ppath_file; do
    [[ -f "${_ppath_file}" ]] || continue
    local _dir
    _dir="$(cat "${_ppath_file}")"
    [[ -d "${_dir}" ]] || continue
    [[ -f "${_dir}/.ai/telamon/telamon.jsonc" ]] || continue
    echo "${_dir}"
  done < <(find "${TELAMON_ROOT}/storage/graphify" -name ".project-path" 2>/dev/null || true)
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd_add() {
  local url="${1:-}"
  if [[ -z "${url}" ]]; then
    echo "Error: 'telamon module add' requires a URL" >&2
    echo >&2
    _usage >&2
    exit 1
  fi
  shift

  # Parse optional path overrides
  local opt_commands="" opt_agents="" opt_skills="" opt_plugins=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --commands=*) opt_commands="${1#*=}"; shift ;;
      --agents=*)   opt_agents="${1#*=}";   shift ;;
      --skills=*)   opt_skills="${1#*=}";   shift ;;
      --plugins=*)  opt_plugins="${1#*=}";  shift ;;
      *) echo "Error: unknown option '$1'" >&2; exit 1 ;;
    esac
  done

  _ensure_modules_file

  local name
  name="$(_url_to_name "${url}")"

  header "Module add: ${name}"

  # Check for duplicate
  local existing_url
  existing_url="$(_get_module_field "${name}" "url")"
  if [[ -n "${existing_url}" ]]; then
    skip "already registered: ${name}"
    return 0
  fi

  local dest="${TELAMON_ROOT}/$(_derive_path "${url}")"

  # Clone if not already present
  if [[ -d "${dest}/.git" ]]; then
    skip "directory already cloned: ${dest}"
  else
    step "Cloning ${url} → ${dest} ..."
    mkdir -p "$(dirname "${dest}")"
    git clone --depth 1 "${url}" "${dest}" \
      && log "Cloned successfully" \
      || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git clone failed"; exit 1; }
  fi

  # Determine which paths actually exist in the cloned repo
  step "Detecting available paths ..."
  local paths_json
  paths_json="$(python3 - "${dest}" "${opt_commands}" "${opt_agents}" "${opt_skills}" "${opt_plugins}" <<'PYEOF'
import json, sys, os

dest        = sys.argv[1]
opt_cmds    = sys.argv[2]
opt_agents  = sys.argv[3]
opt_skills  = sys.argv[4]
opt_plugins = sys.argv[5]

defaults = {
    "commands": opt_cmds    or "./commands",
    "agents":   opt_agents  or "./agents",
    "skills":   opt_skills  or "./skills",
    "plugins":  opt_plugins or "./plugins",
}

paths = {}
for key, rel in defaults.items():
    abs_path = os.path.normpath(os.path.join(dest, rel))
    if os.path.isdir(abs_path):
        paths[key] = rel

print(json.dumps(paths))
PYEOF
)"

  if [[ "${paths_json}" == "{}" ]]; then
    warn "No standard paths found in ${dest} — registering with default paths anyway"
    paths_json='{"commands":"./commands","agents":"./agents","skills":"./skills","plugins":"./plugins"}'
  else
    log "Found paths: ${paths_json}"
  fi

  # Register in .telamon.jsonc modules section
  step "Registering in .telamon.jsonc ..."
  python3 - "${MODULES_FILE}" "${name}" "${url}" "${paths_json}" <<'PYEOF'
import json, sys, re

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

path      = sys.argv[1]
name      = sys.argv[2]
url       = sys.argv[3]
paths     = json.loads(sys.argv[4])

with open(path) as f:
    data = json.loads(strip(f.read()))

modules = data.get('modules', {})
modules[name] = {"url": url, "paths": paths}
data['modules'] = modules

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
  log "Registered: ${name}"

  # Wire into all known projects
  step "Wiring into projects ..."
  local wired=0
  while IFS= read -r _proj; do
    _wire_module_to_project "${name}" "${dest}" "${paths_json}" "${_proj}"
    wired=$((wired + 1))
  done < <(_discover_projects)

  [[ "${wired}" -eq 0 ]] && info "No initialized projects found — run 'telamon init <path>' to wire later"
}

cmd_remove() {
  local name="${1:-}"
  if [[ -z "${name}" ]]; then
    echo "Error: 'telamon module remove' requires a module name (org/repo)" >&2
    echo >&2
    _usage >&2
    exit 1
  fi

  _ensure_modules_file

  header "Module remove: ${name}"

  # Check if it's a built-in
  local is_builtin
  is_builtin="$(_get_module_field "${name}" "builtin")"
  if [[ "${is_builtin}" == "true" ]]; then
    echo "Error: '${name}' is a built-in module and cannot be removed." >&2
    exit 1
  fi

  # Check if registered
  local existing_url
  existing_url="$(_get_module_field "${name}" "url")"
  if [[ -z "${existing_url}" ]]; then
    warn "Module not found in .telamon.jsonc: ${name}"
  else
    # Remove wiring from all projects first
    step "Removing wiring from projects ..."
    while IFS= read -r _proj; do
      _remove_module_wiring "${name}" "${_proj}"
    done < <(_discover_projects)

    # Remove from .telamon.jsonc modules section
    step "Removing from .telamon.jsonc ..."
    python3 - "${MODULES_FILE}" "${name}" <<'PYEOF'
import json, sys, re

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

path = sys.argv[1]
name = sys.argv[2]

with open(path) as f:
    data = json.loads(strip(f.read()))

modules = data.get('modules', {})
modules.pop(name, None)
data['modules'] = modules

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
    log "Unregistered: ${name}"
  fi

  # Remove vendor directory
  local dest="${TELAMON_ROOT}/vendor/${name}"
  if [[ -d "${dest}" ]]; then
    step "Removing directory ${dest} ..."
    rm -rf "${dest}"
    log "Directory removed"
  else
    skip "directory not found: ${dest}"
  fi
}

cmd_list() {
  _ensure_modules_file

  header "Modules (.telamon.jsonc)"

  local modules_json
  modules_json="$(_read_modules_jsonc)"

  python3 - "${modules_json}" "${TELAMON_ROOT}" <<'PYEOF'
import json, sys, os

modules = json.loads(sys.argv[1])
root    = sys.argv[2]

GREEN  = '\033[0;32m'
RED    = '\033[0;31m'
DIM    = '\033[2m'
CLEAR  = '\033[0m'

for name, entry in modules.items():
    url      = entry.get('url', '')
    builtin  = entry.get('builtin', False)
    dest     = os.path.join(root, 'vendor', name)
    cloned   = os.path.isdir(os.path.join(dest, '.git'))
    tag      = ' [builtin]' if builtin else ''
    status   = f'{GREEN}✔{CLEAR}' if cloned else f'{RED}✖{CLEAR}'
    note     = '' if cloned else ' — not cloned'
    print(f'  {status}  vendor/{name}{tag}  {DIM}({url}){note}{CLEAR}')
PYEOF
}

cmd_sync() {
  _ensure_modules_file

  header "Module sync"

  local modules_json
  modules_json="$(_read_modules_jsonc)"

  # Collect project list
  local -a projects=()
  while IFS= read -r _proj; do
    projects+=("${_proj}")
  done < <(_discover_projects)

  if [[ "${#projects[@]}" -eq 0 ]]; then
    info "No initialized projects found."
    return 0
  fi

  # For each module, wire into each project
  local _module_lines
  _module_lines="$(python3 -c "
import json, sys
modules = json.loads(sys.argv[1])
for name, entry in modules.items():
    paths = entry.get('paths', {'commands': './commands', 'agents': './agents', 'skills': './skills', 'plugins': './plugins'})
    print(name + '\t' + json.dumps(paths))
" "${modules_json}")"

  while IFS=$'\t' read -r _name _paths_json; do
    local _dest="${TELAMON_ROOT}/vendor/${_name}"
    if [[ ! -d "${_dest}/.git" ]]; then
      # Try to clone it
      local _url
      _url="$(_get_module_field "${_name}" "url")"
      if [[ -n "${_url}" ]]; then
        step "Cloning ${_name} ..."
        mkdir -p "$(dirname "${_dest}")"
        git clone --depth 1 "${_url}" "${_dest}" \
          && log "Cloned: ${_name}" \
          || { warn "git clone failed for ${_name}"; continue; }
      else
        warn "Module ${_name} not cloned and no URL found — skipping"
        continue
      fi
    fi

    for _proj in "${projects[@]+"${projects[@]}"}"; do
      _wire_module_to_project "${_name}" "${_dest}" "${_paths_json}" "${_proj}"
    done
  done <<< "${_module_lines}"

  log "Sync complete (${#projects[@]} project(s))"
}

_usage() {
  cat <<'EOF'
Usage: telamon module <subcommand> [args]

Subcommands:
  add <url> [--commands=<path>] [--agents=<path>] [--skills=<path>] [--plugins=<path>]
               Clone a git repo into vendor/ and register in .telamon.jsonc
  remove <name>  Remove a module (name is org/repo); cannot remove built-in modules
  list           Show all registered modules with clone status
  sync           Re-wire all modules into all initialized projects
EOF
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

SUBCMD="${1:-}"
shift || true

case "${SUBCMD}" in
  add)    cmd_add    "$@" ;;
  remove) cmd_remove "$@" ;;
  list)   cmd_list        ;;
  sync)   cmd_sync        ;;
  help|"") _usage ;;
  *) echo "Error: unknown module subcommand '${SUBCMD}'" >&2; echo >&2; _usage >&2; exit 1 ;;
esac

#!/usr/bin/env bash
# =============================================================================
# bin/init.sh
# Initialise a project to use Telamon.
#
# Usage:
#   bin/init.sh [--memory-owner=telamon|project] [--ogham-db=telamon|<url>] [--with-tests] <path/to/project>
#
# What it does (delegated to per-app init scripts):
#   obsidian      — vault scaffold + .ai/telamon/memory symlink
#   opencode      — skills symlink, plugins symlink, telamon.jsonc, secrets
#                   symlink, opencode.jsonc symlink/merge, AGENTS.md
#   codebase-index — writes .opencode/codebase-index.json
#   repomix       — writes repomix.config.json
#   graphify      — graphify-out symlink + MCP wrapper + scheduled updates
#   qmd           — vault collections + initial semantic index
#   promptfoo     — agent eval scaffold (only with --with-tests)
#
# After per-app init, wires external modules from .telamon.jsonc into
# .opencode/{skills,agents,plugins,commands}/<module-name>.
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${TELAMON_ROOT}/src/install"

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# ── Flag parsing ──────────────────────────────────────────────────────────────
MEMORY_OWNER_FLAG=""
OGHAM_DB_FLAG=""
WITH_TESTS="false"
POSITIONAL_ARGS=()

for _arg in "$@"; do
  case "${_arg}" in
    --memory-owner=*)
      MEMORY_OWNER_FLAG="${_arg#--memory-owner=}"
      ;;
    --ogham-db=*)
      OGHAM_DB_FLAG="${_arg#--ogham-db=}"
      ;;
    --with-tests)
      WITH_TESTS="true"
      ;;
    *)
      POSITIONAL_ARGS+=("${_arg}")
      ;;
  esac
done

# ── Argument ──────────────────────────────────────────────────────────────────
PROJ="${POSITIONAL_ARGS[0]:-}"
if [[ -z "${PROJ}" ]]; then
  echo "Usage: $0 [--memory-owner=telamon|project] [--ogham-db=telamon|<url>] [--with-tests] <path/to/project>" >&2
  exit 1
fi

if [[ ! -d "${PROJ}" ]]; then
  echo "Error: project path does not exist: ${PROJ}" >&2
  exit 1
fi

PROJ="$(cd "${PROJ}" && pwd)"
PROJECT_NAME="$(basename "${PROJ}")"

# ── Resolve MEMORY_OWNER ──────────────────────────────────────────────────────
# Priority: CLI flag > existing telamon.jsonc > interactive prompt > default (telamon)
MEMORY_OWNER=""

if [[ -n "${MEMORY_OWNER_FLAG}" ]]; then
  # Validate flag value
  if [[ "${MEMORY_OWNER_FLAG}" != "telamon" && "${MEMORY_OWNER_FLAG}" != "project" ]]; then
    echo "Error: --memory-owner must be 'telamon' or 'project', got: ${MEMORY_OWNER_FLAG}" >&2
    exit 1
  fi
  MEMORY_OWNER="${MEMORY_OWNER_FLAG}"
else
  # Check existing telamon.jsonc (re-init scenario)
  _ini_file="${PROJ}/.ai/telamon/telamon.jsonc"
  if [[ -f "${_ini_file}" ]]; then
    _existing="$(config.read_ini "${_ini_file}" "memory_owner" 2>/dev/null || true)"
    if [[ -n "${_existing}" ]]; then
      MEMORY_OWNER="${_existing}"
      info "Memory owner from telamon.jsonc: ${MEMORY_OWNER}"
    fi
  fi

  # Interactive prompt if still unset and stdin is a TTY
  if [[ -z "${MEMORY_OWNER}" ]]; then
    if [[ -t 0 ]]; then
      echo
      echo "? Memory file ownership for ${PROJECT_NAME}:"
      echo "  1) telamon — files in Telamon storage, symlink in project (default)"
      echo "  2) project — files in project, symlink in Telamon storage"
      echo
      printf "? Your choice [1]: "
      read -r _choice
      case "${_choice}" in
        2) MEMORY_OWNER="project" ;;
        *) MEMORY_OWNER="telamon" ;;
      esac
    else
      MEMORY_OWNER="telamon"
    fi
  fi
fi

export TELAMON_ROOT INSTALL_PATH PROJ PROJECT_NAME MEMORY_OWNER WITH_TESTS

# ── Resolve OGHAM_DB ──────────────────────────────────────────────────────────
# Priority: CLI flag > existing telamon.jsonc > interactive prompt > default (telamon)
OGHAM_DB=""
OGHAM_DB_URL=""

if [[ -n "${OGHAM_DB_FLAG}" ]]; then
  if [[ "${OGHAM_DB_FLAG}" == "telamon" ]]; then
    OGHAM_DB="telamon"
  else
    # Treat any other value as a PostgreSQL URL (external mode)
    OGHAM_DB="external"
    OGHAM_DB_URL="${OGHAM_DB_FLAG}"
  fi
else
  # Check existing telamon.jsonc (re-init scenario)
  _ini_file="${PROJ}/.ai/telamon/telamon.jsonc"
  if [[ -f "${_ini_file}" ]]; then
    _existing_ogham="$(config.read_ini "${_ini_file}" "ogham_db" 2>/dev/null || true)"
    if [[ -n "${_existing_ogham}" ]]; then
      OGHAM_DB="${_existing_ogham}"
      info "Ogham database from telamon.jsonc: ${OGHAM_DB}"
    fi
  fi

  # Interactive prompt if still unset and stdin is a TTY
  if [[ -z "${OGHAM_DB}" ]]; then
    if [[ -t 0 ]]; then
      echo
      echo "? Ogham database for ${PROJECT_NAME}:"
      echo "  1) telamon — local Postgres managed by Telamon (default)"
      echo "  2) external — provide a PostgreSQL connection URL"
      echo
      printf "? Your choice [1]: "
      read -r _ogham_choice
      case "${_ogham_choice}" in
        2)
          OGHAM_DB="external"
          printf "? PostgreSQL URL: "
          read -r OGHAM_DB_URL
          ;;
        *)
          OGHAM_DB="telamon"
          ;;
      esac
    else
      OGHAM_DB="telamon"
    fi
  fi
fi

export OGHAM_DB OGHAM_DB_URL

header "Telamon init — ${PROJECT_NAME}"

# ── Run per-app init scripts ──────────────────────────────────────────────────
INIT_APPS=(obsidian opencode codebase-index repomix promptfoo graphify qmd session-capture discord-bridge)

for _app in "${INIT_APPS[@]}"; do
  _script="${INSTALL_PATH}/${_app}/init.sh"
  if [[ ! -f "${_script}" ]]; then
    warn "No init.sh for ${_app} — skipping"
    continue
  fi
  (cd "${PROJ}" && timed_run "${_app}" bash "${_script}")
done

# ── Wire external modules ─────────────────────────────────────────────────────
_telamon_cfg="${TELAMON_ROOT}/.telamon.jsonc"
if [[ -f "${_telamon_cfg}" ]]; then
  _module_lines="$(python3 - "${_telamon_cfg}" <<'PYEOF'
import json, re, sys, os

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

def url_to_vendor(url):
    url = url.rstrip('/').removesuffix('.git')
    if url.startswith('git@'):
        return 'vendor/' + url.split(':',1)[1]
    parts = url.split('://',1)[1].split('/',2)
    return 'vendor/' + ('/'.join(parts[1:]) if len(parts) > 2 else parts[-1])

with open(sys.argv[1]) as f:
    data = json.loads(strip(f.read()))

for name, entry in data.get('modules', {}).items():
    local_path = entry.get('local_path', '')
    url        = entry.get('url', '')
    paths      = entry.get('paths', {})
    if local_path and paths:
        # local module: vendor path is the local_path itself (wiring uses it directly)
        print(f'{name}\t\t{local_path}\t{json.dumps(paths)}')
    elif url and paths:
        print(f'{name}\t{url_to_vendor(url)}\t\t{json.dumps(paths)}')
PYEOF
)"

  if [[ -n "${_module_lines}" ]]; then
    header "External modules"
    while IFS=$'\t' read -r _mname _mvendor _mlocal _mpaths; do
      if [[ -n "${_mlocal}" ]]; then
        # Local module: wire directly from local_path
        if [[ ! -d "${_mlocal}" ]]; then
          skip "${_mname}: local path not found (${_mlocal}) — skipping"
          continue
        fi
        _msrc="${_mlocal}"
      else
        _mdest="${TELAMON_ROOT}/${_mvendor}"
        # Accept either a cloned .git dir or a symlink pointing to a directory
        if [[ ! -d "${_mdest}" ]] && [[ ! -L "${_mdest}" ]]; then
          skip "${_mname}: not cloned — run 'telamon module sync' to clone"
          continue
        fi
        _msrc="${_mdest}"
      fi
      for _type in skills plugins agents commands; do
        _rel="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2],''))" "${_mpaths}" "${_type}")"
        [[ -z "${_rel}" ]] && continue
        _src="$(cd "${_msrc}" && cd "${_rel}" 2>/dev/null && pwd)" || continue
        [[ -d "${_src}" ]] || continue
        _link="${PROJ}/.opencode/${_type}/${_mname}"
        mkdir -p "${PROJ}/.opencode/${_type}"
        if [[ -L "${_link}" ]]; then
          skip ".opencode/${_type}/${_mname} (already exists)"
        elif [[ -e "${_link}" ]]; then
          warn ".opencode/${_type}/${_mname} exists but is not a symlink — skipping"
        else
          ln -s "${_src}" "${_link}"
          log "Symlinked .opencode/${_type}/${_mname} → ${_src}"
        fi
      done
    done <<< "${_module_lines}"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
if [[ "${MEMORY_OWNER}" == "project" ]]; then
  BRAIN_DIR="${PROJ}/.ai/telamon/memory/brain"
else
  BRAIN_DIR="${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}/brain"
fi
echo
log "Project '${PROJECT_NAME}' initialised."
info "Memory notes: ${BRAIN_DIR}/"
info "Edit ${BRAIN_DIR}/memories.md to record project lessons."
echo -e "  ${TEXT_DIM}⏱  Total init time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"

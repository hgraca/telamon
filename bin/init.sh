#!/usr/bin/env bash
# =============================================================================
# bin/init.sh
# Initialise a project to use Telamon.
#
# Usage:
#   bin/init.sh [--memory-owner=telamon|project] [--with-tests] <path/to/project>
#
# What it does (delegated to per-app init scripts):
#   opencode      — skills symlink, plugins symlink, telamon.jsonc, secrets
#                   symlink, opencode.jsonc symlink/merge, AGENTS.md
#   codebase-index — writes .opencode/codebase-index.json
#   repomix       — writes repomix.config.json
#   graphify      — graphify-out symlink + MCP wrapper + scheduled updates
#   qmd           — vault collections + initial semantic index
#   promptfoo     — agent eval scaffold (only with --with-tests)
#
# After per-app init, wires external modules from .telamon.jsonc into
# .opencode/{skills,agents,plugins,commands,scripts}/<module-name>.
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREREQUISITES_PATH="${TELAMON_ROOT}/src/prerequisites"
MODULES_PATH="${TELAMON_ROOT}/src/modules"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# ── Flag parsing ──────────────────────────────────────────────────────────────
MEMORY_OWNER_FLAG=""
WITH_TESTS="false"
POSITIONAL_ARGS=()

for _arg in "$@"; do
  case "${_arg}" in
    --memory-owner=*)
      MEMORY_OWNER_FLAG="${_arg#--memory-owner=}"
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
  echo "Usage: $0 [--memory-owner=telamon|project] [--with-tests] <path/to/project>" >&2
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

export TELAMON_ROOT PREREQUISITES_PATH MODULES_PATH FUNCTIONS_PATH PROJ PROJECT_NAME MEMORY_OWNER WITH_TESTS

header "Telamon init — ${PROJECT_NAME}"

# Detect first-time init before any per-app scripts run (they create the file).
_FIRST_TIME_INIT="false"
if [[ ! -f "${PROJ}/.ai/telamon/telamon.jsonc" ]]; then
  _FIRST_TIME_INIT="true"
fi

# ── Run per-app init scripts ──────────────────────────────────────────────────
INIT_APPS=(opencode codebase-index repomix promptfoo memory graphify qmd git-hook-remember-session)

for _app in "${INIT_APPS[@]}"; do
  _dir=$(_resolve_app_path "${_app}") || {
    warn "App '${_app}' not found in prerequisites/ or modules/ — skipping"
    continue
  }
  _script="${_dir}/init.sh"
  if [[ ! -f "${_script}" ]]; then
    warn "No init.sh for ${_app} — skipping"
    continue
  fi
  (cd "${PROJ}" && timed_run "${_app}" bash "${_script}")
done

# ── Project config wizard (first-time only) ───────────────────────────────────
# On the very first 'telamon init' for a project, walk the user through the
# project-scoped settings so they are set correctly from the start.
# Re-runs of 'telamon init' skip this (use 'telamon config' to reconfigure).
if [[ "${_FIRST_TIME_INIT}" == "true" ]] && [[ -t 0 ]]; then
  header "Project configuration"
  info "First-time init — let's configure your project settings."
  echo ""
  bash "${TELAMON_ROOT}/bin/config.sh" --project="${PROJ}"
fi

# ── .gitignore telamon section ────────────────────────────────────────────────
header ".gitignore"

_GITIGNORE="${PROJ}/.gitignore"
_GI_MARKER_START="###> telamon ###"
_GI_MARKER_END="###< telamon ###"
_GI_SECTION="${_GI_MARKER_START}
.ai/telamon
.graphifyignore
graphify-out
graphify-out/
*opencode*
*claude*
*codex*
*junie*
!opencode.dist.json
!opencode.dist.jsonc
repomix.config.json
.telamon.jsonc
${_GI_MARKER_END}"

if [[ -f "${_GITIGNORE}" ]]; then
  if grep -qF "${_GI_MARKER_START}" "${_GITIGNORE}"; then
    # Extract existing section and compare
    _existing_section="$(sed -n "/^${_GI_MARKER_START//\//\\/}$/,/^${_GI_MARKER_END//\//\\/}$/p" "${_GITIGNORE}")"
    if [[ "${_existing_section}" == "${_GI_SECTION}" ]]; then
      skip ".gitignore telamon section (already up to date)"
    else
      # Replace existing section
      _tmp="$(mktemp)"
      awk -v start="${_GI_MARKER_START}" -v end="${_GI_MARKER_END}" '
        $0 == start { skip=1; next }
        $0 == end   { skip=0; next }
        !skip { print }
      ' "${_GITIGNORE}" > "${_tmp}"
      # Remove trailing blank lines then append section
      sed -i -e :a -e '/^\n*$/{$d;N;ba}' "${_tmp}"
      printf '\n\n%s\n' "${_GI_SECTION}" >> "${_tmp}"
      mv "${_tmp}" "${_GITIGNORE}"
      log ".gitignore telamon section updated"
    fi
  else
    # Append section
    printf '\n%s\n' "${_GI_SECTION}" >> "${_GITIGNORE}"
    log ".gitignore telamon section added"
  fi
else
  # Create .gitignore with section
  printf '%s\n' "${_GI_SECTION}" > "${_GITIGNORE}"
  log ".gitignore created with telamon section"
fi

# ── Wire external modules ─────────────────────────────────────────────────────
_telamon_cfg="${TELAMON_ROOT}/.telamon.jsonc"
if [[ -f "${_telamon_cfg}" ]]; then
  header "External modules"

  # Step 1: Prune stale .opencode/<type>/<name> symlinks whose <name> is no
  # longer a registered module. Mirrors the self-healing pass in update.sh.
  # Only prunes symlinks whose target points into vendor/ or src/instructions/
  # so user-created symlinks are preserved.
  _registered_names="$(python3 - "${_telamon_cfg}" "${FUNCTIONS_PATH}" <<'PYEOF'
import sys
sys.path.insert(0, sys.argv[2])
from strip_jsonc import load_jsonc

with open(sys.argv[1]) as f:
    data = load_jsonc(f.read())

# 'telamon' is the canonical first-party skill bundle (always wired by init).
print('\n'.join(['telamon'] + list(data.get('modules', {}).keys())))
PYEOF
)"

  declare -A _REGISTERED=()
  while IFS= read -r _n; do
    [[ -n "${_n}" ]] && _REGISTERED["${_n}"]=1
  done <<< "${_registered_names}"

  _stale_pruned=0
  for _type in skills plugins agents commands scripts; do
    _type_dir="${PROJ}/.opencode/${_type}"
    [[ -d "${_type_dir}" ]] || continue
    for _link in "${_type_dir}"/*; do
      [[ -L "${_link}" ]] || continue
      _name="$(basename "${_link}")"
      if [[ -z "${_REGISTERED[${_name}]+x}" ]]; then
        _target="$(readlink "${_link}")"
        if [[ "${_target}" == "${TELAMON_ROOT}/vendor/"* || "${_target}" == "${TELAMON_ROOT}/src/instructions/"* ]]; then
          rm "${_link}"
          log "Pruned stale .opencode/${_type}/${_name}"
          _stale_pruned=$((_stale_pruned + 1))
        fi
      fi
    done
  done

  _module_lines="$(python3 - "${_telamon_cfg}" "${FUNCTIONS_PATH}" <<'PYEOF'
import json, sys, os
sys.path.insert(0, sys.argv[2])
from strip_jsonc import load_jsonc

def url_to_vendor(url):
    url = url.rstrip('/').removesuffix('.git')
    if url.startswith('git@'):
        return 'vendor/' + url.split(':',1)[1]
    parts = url.split('://',1)[1].split('/',2)
    return 'vendor/' + ('/'.join(parts[1:]) if len(parts) > 2 else parts[-1])

with open(sys.argv[1]) as f:
    data = load_jsonc(f.read())

# Use ASCII Unit Separator (\x1f) — non-whitespace so bash 'read' does not
# collapse adjacent empty fields (e.g. when local_path or vendor is empty).
SEP = '\x1f'
for name, entry in data.get('modules', {}).items():
    local_path = entry.get('local_path', '')
    url        = entry.get('url', '')
    paths      = entry.get('paths', {})
    if local_path and paths:
        # local module: vendor path is the local_path itself (wiring uses it directly)
        print(name + SEP + '' + SEP + local_path + SEP + json.dumps(paths))
    elif url and paths:
        print(name + SEP + url_to_vendor(url) + SEP + '' + SEP + json.dumps(paths))
PYEOF
)"

  if [[ -n "${_module_lines}" ]]; then
    while IFS=$'\x1f' read -r _mname _mvendor _mlocal _mpaths; do
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
      for _type in skills plugins agents commands scripts; do
        _rel="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2],''))" "${_mpaths}" "${_type}")"
        [[ -z "${_rel}" ]] && continue
        _src="$(cd "${_msrc}" && cd "${_rel}" 2>/dev/null && pwd)" || continue
        [[ -d "${_src}" ]] || continue
        _link="${PROJ}/.opencode/${_type}/${_mname}"
        mkdir -p "${PROJ}/.opencode/${_type}"
        ensure_symlink "${_link}" "${_src}" ".opencode/${_type}/${_mname}"
      done
    done <<< "${_module_lines}"
  fi
fi

# ──BEGIN telamon.explore-project block──
# ── Project description (telamon.explore-project) ─────────────────────────────
# If <PROJ>/.ai/telamon/memory/bootstrap/project.md is missing or empty,
# synchronously invoke `opencode run` so the telamon.explore-project skill writes
# the canonical project map for future agent sessions. Idempotent: skip when the
# description is already populated. Symlink-transparent: bash's `-s` test follows
# symlinks, so MEMORY_OWNER=telamon (where the file lives under
# storage/memory/projects/<name>/bootstrap/ and is exposed via the
# .ai/telamon/memory symlink) is handled identically to MEMORY_OWNER=project.
# Missing `opencode` → warn + continue (exploration is enhancement, not a hard
# requirement). `opencode run` failure → warn + continue. Init never aborts here.
#
# NB: The two sentinels (BEGIN/END) are load-bearing: tests/bin/init-explore.test.sh
# extracts this block by name and sources it in isolation. Edit them with care.

header "Project description"

_DESC_FILE="${PROJ}/.ai/telamon/memory/bootstrap/project.md"

if [[ -s "${_DESC_FILE}" ]]; then
  info "Project description already present — skipping exploration"
elif ! command -v opencode >/dev/null 2>&1; then
  warn "opencode not on PATH — skipping project exploration. Install opencode and re-run 'telamon init' to generate the project description, or run the telamon.explore-project skill manually."
else
  info "Exploring project — this may take several minutes…"
  _explore_prompt="Use the telamon.explore-project skill to map this project and write the project description."
  if opencode run \
      --agent telamon \
      --dir "${PROJ}" \
      --dangerously-skip-permissions \
      "${_explore_prompt}"; then
    if [[ -s "${_DESC_FILE}" ]]; then
      log "Project exploration complete"
    else
      warn "opencode run completed but description.md is still empty — re-run 'telamon init' or invoke telamon.explore-project manually."
    fi
  else
    warn "opencode run exited with non-zero status — project description not generated. Re-run 'telamon init' or invoke telamon.explore-project manually."
  fi
  unset _explore_prompt
fi

unset _DESC_FILE
# ──END telamon.explore-project block──

# ── Done ──────────────────────────────────────────────────────────────────────
if [[ "${MEMORY_OWNER}" == "project" ]]; then
  LATENT_DIR="${PROJ}/.ai/telamon/memory/latent"
else
  LATENT_DIR="${TELAMON_ROOT}/storage/memory/projects/${PROJECT_NAME}/latent"
fi
echo
log "Project '${PROJECT_NAME}' initialised."
info "Memory notes: ${LATENT_DIR}/"
info "Edit ${LATENT_DIR}/memories.md to record project lessons."
echo -e "  ${TEXT_DIM}⏱  Total init time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"

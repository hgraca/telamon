#!/usr/bin/env bash
# =============================================================================
# bin/config.sh
# Interactive configuration wizard for Telamon.
#
# Usage:
#   bin/config.sh [--global] [--project=<path>]
#
# Modes:
#   (no flags)          Configure both global (.telamon.jsonc) and, if the
#                       current directory is an initialised project, its local
#                       .ai/telamon/telamon.jsonc.
#   --global            Configure only the global .telamon.jsonc.
#   --project=<path>    Configure only the project telamon.jsonc at <path>.
#                       Used by 'telamon init' on first-time project setup.
#
# Behaviour:
#   - Existing values are shown in [brackets] as the default.
#   - Keys with no value yet show an example hint like (ie. ...).
#   - Pressing Enter without input keeps the current/default value.
#   - Boolean fields accept: true / false / yes / no / 1 / 0.
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# ── Flag parsing ──────────────────────────────────────────────────────────────
MODE="auto"          # auto | global | project
PROJECT_DIR=""

for _arg in "$@"; do
  case "${_arg}" in
    --global)
      MODE="global"
      ;;
    --project=*)
      MODE="project"
      PROJECT_DIR="${_arg#--project=}"
      ;;
    *)
      echo "Usage: $0 [--global] [--project=<path>]" >&2
      exit 1
      ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────

# _prompt_value <label> <description> <current_value> <example>
#
# Prints a labelled prompt. Shows [current] if set, or (ie. example) if not.
# Reads user input; returns the new value (or current if user pressed Enter).
_prompt_value() {
  local label="$1"
  local description="$2"
  local current="$3"
  local example="$4"

  local hint=""
  if [[ -n "${current}" ]]; then
    hint="${TEXT_DIM}[${current}]${TEXT_CLEAR}"
  elif [[ -n "${example}" ]]; then
    hint="${TEXT_DIM}(ie. ${example})${TEXT_CLEAR}"
  fi

  echo -e "  ${TEXT_BOLD}${label}${TEXT_CLEAR}  ${TEXT_DIM}${description}${TEXT_CLEAR}"
  echo -en "  ${TEXT_YELLOW}?${TEXT_CLEAR}  Value ${hint}: "

  local reply
  read -r reply </dev/tty

  if [[ -z "${reply}" ]]; then
    echo "${current}"
  else
    echo "${reply}"
  fi
}

# _prompt_bool <label> <description> <current_value> <default>
#
# Like _prompt_value but normalises the answer to "true" or "false".
_prompt_bool() {
  local label="$1"
  local description="$2"
  local current="$3"
  local default="${4:-true}"

  local display="${current:-${default}}"
  local hint="${TEXT_DIM}[${display}]${TEXT_CLEAR} ${TEXT_DIM}(true/false)${TEXT_CLEAR}"

  echo -e "  ${TEXT_BOLD}${label}${TEXT_CLEAR}  ${TEXT_DIM}${description}${TEXT_CLEAR}"
  echo -en "  ${TEXT_YELLOW}?${TEXT_CLEAR}  Value ${hint}: "

  local reply
  read -r reply </dev/tty
  reply="${reply,,}"  # lowercase

  if [[ -z "${reply}" ]]; then
    echo "${display}"
    return
  fi

  case "${reply}" in
    true|yes|1)  echo "true"  ;;
    false|no|0)  echo "false" ;;
    *)
      warn "Invalid boolean '${reply}' — keeping '${display}'"
      echo "${display}"
      ;;
  esac
}

# _prompt_select <label> <description> <current_value> <opt1> [<opt2> ...]
#
# Numbered menu. User picks a number or types 'c' for custom.
_prompt_select() {
  local label="$1"
  local description="$2"
  local current="$3"
  shift 3
  local -a options=("$@")

  echo -e "  ${TEXT_BOLD}${label}${TEXT_CLEAR}  ${TEXT_DIM}${description}${TEXT_CLEAR}"
  if [[ -n "${current}" ]]; then
    echo -e "  ${TEXT_DIM}Current: ${current}${TEXT_CLEAR}"
  fi

  local i
  for i in "${!options[@]}"; do
    echo -e "    ${TEXT_DIM}$(( i + 1 )))${TEXT_CLEAR} ${options[${i}]}"
  done
  echo -e "    ${TEXT_DIM}c)${TEXT_CLEAR} Custom — type your own"
  echo ""

  local chosen=""
  while [[ -z "${chosen}" ]]; do
    local default_num=1
    echo -en "  ${TEXT_YELLOW}?${TEXT_CLEAR}  Choice [${default_num}]: "
    local reply
    read -r reply </dev/tty
    reply="${reply,,}"

    if [[ -z "${reply}" ]]; then
      chosen="${options[0]}"
    elif [[ "${reply}" == "c" ]]; then
      echo -en "  ${TEXT_YELLOW}?${TEXT_CLEAR}  Enter value: "
      read -r chosen </dev/tty
      chosen="${chosen// /}"
      if [[ -z "${chosen}" ]]; then
        warn "Empty input — please try again."
        chosen=""
      fi
    elif [[ "${reply}" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= ${#options[@]} )); then
      chosen="${options[$(( reply - 1 ))]}"
    else
      warn "Invalid choice — enter a number between 1 and ${#options[@]}, or 'c'."
    fi
  done

  echo "${chosen}"
}

# _read_cfg <file> <key>  — silent wrapper; returns empty string on miss
_read_cfg() {
  config.read_ini "$1" "$2" 2>/dev/null || true
}

# _write_cfg <file> <key> <value>  — only writes when value is non-empty
_write_cfg() {
  local file="$1" key="$2" value="$3"
  [[ -n "${value}" ]] || return 0
  config.write_ini "${file}" "${key}" "${value}"
}

# ── Guard: must be interactive ────────────────────────────────────────────────
if [[ ! -t 0 ]]; then
  warn "stdin is not a TTY — cannot run config wizard interactively"
  exit 1
fi

# =============================================================================
# SECTION A — Global config: .telamon.jsonc
# =============================================================================
_configure_global() {
  local cfg="${TELAMON_ROOT}/.telamon.jsonc"

  if [[ ! -f "${cfg}" ]]; then
    warn ".telamon.jsonc not found at ${cfg} — run 'make install' first"
    return 1
  fi

  header "Global Telamon config  (.telamon.jsonc)"
  echo -e "  ${TEXT_DIM}Press Enter to keep the current value shown in [brackets].${TEXT_CLEAR}"
  echo ""

  # ── bun_version ─────────────────────────────────────────────────────────────
  local cur_bun; cur_bun="$(_read_cfg "${cfg}" "bun_version")"
  local new_bun
  new_bun="$(_prompt_value \
    "bun_version" \
    "Required Bun runtime version constraint (semver range)" \
    "${cur_bun}" \
    "^1.3.13")"
  _write_cfg "${cfg}" "bun_version" "${new_bun}"

  # ── skill.gather-context.context-cache.ttl ──────────────────────────────────
  # Stored as a nested object; read/write the whole skill block via Python.
  local cur_ttl
  cur_ttl="$(python3 - "${FUNCTIONS_PATH}" "${cfg}" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[1])
from strip_jsonc import load_jsonc
with open(sys.argv[2]) as f:
    data = load_jsonc(f.read())
ttl = data.get("skill", {}).get("gather-context", {}).get("context-cache", {}).get("ttl", "")
print(ttl)
PYEOF
  )"

  echo ""
  echo -e "  ${TEXT_BOLD}skill.gather-context.context-cache.ttl${TEXT_CLEAR}  ${TEXT_DIM}Cache TTL for gather-context reports (Nd | Nh | Nm)${TEXT_CLEAR}"
  local hint_ttl=""
  if [[ -n "${cur_ttl}" ]]; then
    hint_ttl="${TEXT_DIM}[${cur_ttl}]${TEXT_CLEAR}"
  else
    hint_ttl="${TEXT_DIM}(ie. 7d)${TEXT_CLEAR}"
  fi
  echo -en "  ${TEXT_YELLOW}?${TEXT_CLEAR}  Value ${hint_ttl}: "
  local new_ttl
  read -r new_ttl </dev/tty

  if [[ -z "${new_ttl}" ]]; then
    new_ttl="${cur_ttl}"
  fi

  if [[ -n "${new_ttl}" ]]; then
    python3 - "${FUNCTIONS_PATH}" "${cfg}" "${new_ttl}" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[1])
from strip_jsonc import load_jsonc

path = sys.argv[2]
ttl  = sys.argv[3]

with open(path) as f:
    data = load_jsonc(f.read())

skill = data.setdefault("skill", {})
gc    = skill.setdefault("gather-context", {})
cc    = gc.setdefault("context-cache", {})
cc["ttl"] = ttl

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
  fi

  echo ""
  log "Global config saved → ${cfg}"
}

# =============================================================================
# SECTION B — Project config: .ai/telamon/telamon.jsonc
# =============================================================================
_configure_project() {
  local proj_dir="$1"
  local cfg="${proj_dir}/.ai/telamon/telamon.jsonc"

  if [[ ! -f "${cfg}" ]]; then
    warn "Project config not found: ${cfg}"
    warn "Run 'telamon init ${proj_dir}' first."
    return 1
  fi

  local proj_name; proj_name="$(basename "${proj_dir}")"
  header "Project config  (${proj_name}/.ai/telamon/telamon.jsonc)"
  echo -e "  ${TEXT_DIM}Press Enter to keep the current value shown in [brackets].${TEXT_CLEAR}"
  echo ""

  # ── project_name ────────────────────────────────────────────────────────────
  local cur_name; cur_name="$(_read_cfg "${cfg}" "project_name")"
  local new_name
  new_name="$(_prompt_value \
    "project_name" \
    "Human-readable project name used in agent prompts" \
    "${cur_name}" \
    "${proj_name}")"
  _write_cfg "${cfg}" "project_name" "${new_name}"

  echo ""

  # ── memory_owner ────────────────────────────────────────────────────────────
  local cur_owner; cur_owner="$(_read_cfg "${cfg}" "memory_owner")"
  echo -e "  ${TEXT_BOLD}memory_owner${TEXT_CLEAR}  ${TEXT_DIM}Where memory files live: 'telamon' (Telamon storage, symlink in project) or 'project' (in project, symlink in Telamon)${TEXT_CLEAR}"
  if [[ -n "${cur_owner}" ]]; then
    echo -e "  ${TEXT_DIM}Current: ${cur_owner}${TEXT_CLEAR}"
  fi
  echo -e "    ${TEXT_DIM}1)${TEXT_CLEAR} telamon  ${TEXT_DIM}(files in Telamon storage — default)${TEXT_CLEAR}"
  echo -e "    ${TEXT_DIM}2)${TEXT_CLEAR} project  ${TEXT_DIM}(files in project repo)${TEXT_CLEAR}"
  echo ""
  echo -en "  ${TEXT_YELLOW}?${TEXT_CLEAR}  Choice [${cur_owner:-1}]: "
  local _mo_reply
  read -r _mo_reply </dev/tty
  local new_owner
  case "${_mo_reply}" in
    2|project) new_owner="project" ;;
    1|telamon|"") new_owner="${cur_owner:-telamon}" ;;
    *) warn "Invalid choice — keeping '${cur_owner:-telamon}'"; new_owner="${cur_owner:-telamon}" ;;
  esac
  _write_cfg "${cfg}" "memory_owner" "${new_owner}"

  echo ""

  # ── medium_model ────────────────────────────────────────────────────────────
  local cur_medium; cur_medium="$(_read_cfg "${cfg}" "medium_model")"
  # Build suggestions from opencode.jsonc
  local opencode_jsonc=""
  local _sym="${proj_dir}/opencode.jsonc"
  [[ -L "${_sym}" ]] && opencode_jsonc="$(readlink -f "${_sym}")"
  if [[ -z "${opencode_jsonc}" || ! -f "${opencode_jsonc}" ]]; then
    opencode_jsonc="${TELAMON_ROOT}/storage/opencode.jsonc"
  fi

  local _main_model="" _small_model=""
  if [[ -f "${opencode_jsonc}" ]]; then
    _main_model="$(python3 - "${FUNCTIONS_PATH}" "${opencode_jsonc}" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[1])
from strip_jsonc import load_jsonc
with open(sys.argv[2]) as f:
    data = load_jsonc(f.read())
print(data.get("model", ""))
PYEOF
    )"
    _small_model="$(python3 - "${FUNCTIONS_PATH}" "${opencode_jsonc}" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[1])
from strip_jsonc import load_jsonc
with open(sys.argv[2]) as f:
    data = load_jsonc(f.read())
print(data.get("small_model", ""))
PYEOF
    )"
  fi

  local -a _model_opts=()
  local _provider_prefix=""
  if [[ "${_main_model}" == */* ]]; then
    _provider_prefix="${_main_model%/*}"
  fi
  if [[ "${_main_model}" == *claude-opus* && "${_small_model}" == *claude-haiku* ]]; then
    _model_opts+=("${_provider_prefix}/claude-sonnet-4")
  elif [[ "${_main_model}" == *gpt-4o && "${_small_model}" == *gpt-4o-mini* ]]; then
    _model_opts+=("${_provider_prefix}/gpt-4.1")
  fi
  [[ -n "${_main_model}" ]]  && _model_opts+=("${_main_model}")
  [[ -n "${_small_model}" ]] && _model_opts+=("${_small_model}")

  local new_medium
  if [[ ${#_model_opts[@]} -gt 0 ]]; then
    new_medium="$(_prompt_select \
      "medium_model" \
      "Model for medium-complexity agent tasks (between main and small)" \
      "${cur_medium}" \
      "${_model_opts[@]}")"
  else
    new_medium="$(_prompt_value \
      "medium_model" \
      "Model for medium-complexity agent tasks (between main and small)" \
      "${cur_medium}" \
      "github-copilot/claude-sonnet-4")"
  fi
  _write_cfg "${cfg}" "medium_model" "${new_medium}"

  echo ""

  # ── rtk_enabled ─────────────────────────────────────────────────────────────
  local cur_rtk; cur_rtk="$(_read_cfg "${cfg}" "rtk_enabled")"
  local new_rtk
  new_rtk="$(_prompt_bool \
    "rtk_enabled" \
    "Enable RTK (Rapid Task Kit) integration" \
    "${cur_rtk}" \
    "true")"
  _write_cfg "${cfg}" "rtk_enabled" "${new_rtk}"

  echo ""

  # ── caveman_enabled ──────────────────────────────────────────────────────────
  local cur_cave; cur_cave="$(_read_cfg "${cfg}" "caveman_enabled")"
  local new_cave
  new_cave="$(_prompt_bool \
    "caveman_enabled" \
    "Enable caveman mode (token-efficient compressed communication)" \
    "${cur_cave}" \
    "true")"
  _write_cfg "${cfg}" "caveman_enabled" "${new_cave}"

  echo ""

  # ── gpu_enabled ──────────────────────────────────────────────────────────────
  local cur_gpu; cur_gpu="$(_read_cfg "${cfg}" "gpu_enabled")"
  local new_gpu
  new_gpu="$(_prompt_bool \
    "gpu_enabled" \
    "Enable GPU support for local models" \
    "${cur_gpu}" \
    "false")"
  _write_cfg "${cfg}" "gpu_enabled" "${new_gpu}"

  echo ""

  # ── docker_gpu_enabled ───────────────────────────────────────────────────────
  local cur_dgpu; cur_dgpu="$(_read_cfg "${cfg}" "docker_gpu_enabled")"
  local new_dgpu
  new_dgpu="$(_prompt_bool \
    "docker_gpu_enabled" \
    "Enable GPU passthrough inside Docker containers" \
    "${cur_dgpu}" \
    "false")"
  _write_cfg "${cfg}" "docker_gpu_enabled" "${new_dgpu}"

  echo ""

  # ── agent_communication.enabled ─────────────────────────────────────────────
  local cur_ac_enabled
  cur_ac_enabled="$(python3 - "${FUNCTIONS_PATH}" "${cfg}" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[1])
from strip_jsonc import load_jsonc
with open(sys.argv[2]) as f:
    data = load_jsonc(f.read())
v = data.get("agent_communication", {}).get("enabled", "")
if isinstance(v, bool):
    print("true" if v else "false")
else:
    print(v)
PYEOF
  )"
  local new_ac_enabled
  new_ac_enabled="$(_prompt_bool \
    "agent_communication.enabled" \
    "Enable structured inter-agent delegation protocol" \
    "${cur_ac_enabled}" \
    "true")"

  echo ""

  # ── agent_communication.max_attempts ────────────────────────────────────────
  local cur_ac_max
  cur_ac_max="$(python3 - "${FUNCTIONS_PATH}" "${cfg}" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[1])
from strip_jsonc import load_jsonc
with open(sys.argv[2]) as f:
    data = load_jsonc(f.read())
print(data.get("agent_communication", {}).get("max_attempts", ""))
PYEOF
  )"
  local new_ac_max
  new_ac_max="$(_prompt_value \
    "agent_communication.max_attempts" \
    "Maximum retry attempts for delegated agent work" \
    "${cur_ac_max}" \
    "2")"

  echo ""

  # ── ogham_db ─────────────────────────────────────────────────────────────────
  local cur_ogham; cur_ogham="$(_read_cfg "${cfg}" "ogham_db")"
  local new_ogham
  new_ogham="$(_prompt_value \
    "ogham_db" \
    "Ogham database name (use 'external' for a separate DB URL)" \
    "${cur_ogham}" \
    "telamon")"
  _write_cfg "${cfg}" "ogham_db" "${new_ogham}"

  # ── Write agent_communication block atomically ───────────────────────────────
  python3 - "${FUNCTIONS_PATH}" "${cfg}" \
    "${new_ac_enabled}" "${new_ac_max}" <<'PYEOF'
import json, sys
sys.path.insert(0, sys.argv[1])
from strip_jsonc import load_jsonc

path       = sys.argv[2]
ac_enabled = sys.argv[3].lower() in ("true", "yes", "1")
ac_max_raw = sys.argv[4]
ac_max     = int(ac_max_raw) if ac_max_raw.isdigit() else 2

with open(path) as f:
    data = load_jsonc(f.read())

ac = data.setdefault("agent_communication", {})
ac["enabled"]      = ac_enabled
ac["max_attempts"] = ac_max
# Preserve exempt_agents if already set
ac.setdefault("exempt_agents", ["repomix-agent", "qmd"])

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

  echo ""
  log "Project config saved → ${cfg}"
}

# =============================================================================
# Main dispatch
# =============================================================================

case "${MODE}" in
  global)
    _configure_global
    ;;

  project)
    if [[ -z "${PROJECT_DIR}" ]]; then
      echo "Error: --project requires a path" >&2
      exit 1
    fi
    [[ "${PROJECT_DIR}" != /* ]] && PROJECT_DIR="$(pwd)/${PROJECT_DIR}"
    _configure_project "${PROJECT_DIR}"
    ;;

  auto)
    # Always configure global
    _configure_global

    # Also configure project if current dir (or PROJ env var) is initialised
    _auto_proj="${PROJ:-$(pwd)}"
    if [[ -f "${_auto_proj}/.ai/telamon/telamon.jsonc" ]]; then
      echo ""
      _configure_project "${_auto_proj}"
    else
      echo ""
      info "No initialised project found at ${_auto_proj} — skipping project config."
      info "Run 'telamon init <path>' to initialise a project, then 'telamon config' again."
    fi
    ;;
esac

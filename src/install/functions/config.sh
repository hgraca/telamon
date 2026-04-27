#!/usr/bin/env bash
# Shared helpers for reading and writing telamon.jsonc config files.
#
# Format: JSONC (JSON with // comments). Keys are flat top-level strings.

# config.read_ini <file> <key>
#
# Reads a top-level string value from a JSONC config file.
# Returns 1 if the file does not exist or the key is not found / empty.
#
# Usage:
#   value="$(config.read_ini /path/to/telamon.jsonc medium_model)"
config.read_ini() {
  local file="$1" key="$2"
  [[ -f "${file}" ]] || return 1
  local val
  val="$(python3 - "${file}" "${key}" <<'PYEOF'
import json, re, sys

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

with open(sys.argv[1]) as f:
    data = json.loads(strip(f.read()))

val = data.get(sys.argv[2], '')
if isinstance(val, bool):
    print('true' if val else 'false')
elif isinstance(val, dict) or isinstance(val, list):
    print(json.dumps(val))
elif val is None:
    pass
else:
    print(val)
PYEOF
)" || return 1
  [[ -n "${val}" ]] || return 1
  echo "${val}"
}

# config.write_ini <file> <key> <value>
#
# Sets or updates a top-level key in a JSONC config file.
# Preserves comments and formatting as much as possible.
#
# Usage:
#   config.write_ini /path/to/telamon.jsonc medium_model "github-copilot/claude-sonnet-4"
config.write_ini() {
  local file="$1" key="$2" value="$3"

  python3 - "${file}" "${key}" "${value}" <<'PYEOF'
import json, re, sys

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

path  = sys.argv[1]
key   = sys.argv[2]
value = sys.argv[3]

with open(path) as f:
    raw = f.read()

data = json.loads(strip(raw))

# Coerce string booleans
if value.lower() == 'true':
    data[key] = True
elif value.lower() == 'false':
    data[key] = False
else:
    data[key] = value

# Rewrite the file preserving indentation style
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
}

# config.resolve_medium_model <project_dir>
#
# Lazy resolution of the medium_model setting:
#   1. If medium_model is already set in telamon.jsonc, echo it and return 0.
#   2. Otherwise, read model + small_model from opencode.jsonc, build a
#      suggestion list, interactively prompt the user, persist the choice,
#      and echo the chosen model.
#
# Returns 1 if stdin is not a TTY (non-interactive) or on any error.
#
# Usage:
#   medium="$(config.resolve_medium_model /path/to/project)"
config.resolve_medium_model() {
  local project_dir="$1"
  local ini_file="${project_dir}/.ai/telamon/telamon.jsonc"
  local project_name
  project_name="$(basename "${project_dir}")"

  # ── 1. Return early if already configured ────────────────────────────────────
  local existing
  if existing="$(config.read_ini "${ini_file}" "medium_model")" && [[ -n "${existing}" ]]; then
    echo "${existing}"
    return 0
  fi

  # ── 2. Resolve opencode.jsonc path ───────────────────────────────────────────
  local opencode_jsonc=""
  local symlink_candidate="${project_dir}/opencode.jsonc"
  if [[ -L "${symlink_candidate}" ]]; then
    opencode_jsonc="$(readlink -f "${symlink_candidate}")"
  fi
  if [[ -z "${opencode_jsonc}" || ! -f "${opencode_jsonc}" ]]; then
    # Fall back to Telamon's own storage copy
    local telamon_root
    telamon_root="$(cd "${INSTALL_PATH}/../.." && pwd)"
    opencode_jsonc="${telamon_root}/storage/opencode.jsonc"
  fi
  if [[ ! -f "${opencode_jsonc}" ]]; then
    warn "opencode.jsonc not found — cannot resolve medium_model"
    return 1
  fi

  # ── 3. Read model + small_model from opencode.jsonc ──────────────────────────
  local main_model small_model
  main_model="$(python3 - "${INSTALL_PATH}/functions/strip_jsonc.py" "${opencode_jsonc}" <<'PYEOF'
import json, sys
exec(open(sys.argv[1]).read())
with open(sys.argv[2]) as f:
    cfg = json.loads(strip_jsonc_comments(f.read()))
print(cfg.get("model", ""))
PYEOF
)"
  small_model="$(python3 - "${INSTALL_PATH}/functions/strip_jsonc.py" "${opencode_jsonc}" <<'PYEOF'
import json, sys
exec(open(sys.argv[1]).read())
with open(sys.argv[2]) as f:
    cfg = json.loads(strip_jsonc_comments(f.read()))
print(cfg.get("small_model", ""))
PYEOF
)"

  # ── 4. Derive provider prefix and intermediate suggestion ─────────────────────
  # Provider prefix = everything before the last '/' segment
  local provider_prefix=""
  if [[ "${main_model}" == */* ]]; then
    provider_prefix="${main_model%/*}"
  fi

  local intermediate_model=""
  if [[ "${main_model}" == *claude-opus* && "${small_model}" == *claude-haiku* ]]; then
    intermediate_model="${provider_prefix}/claude-sonnet-4"
  elif [[ "${main_model}" == *gpt-4o && "${small_model}" == *gpt-4o-mini* ]]; then
    intermediate_model="${provider_prefix}/gpt-4.1"
  fi

  # ── 5. Guard: must be interactive ────────────────────────────────────────────
  if [[ ! -t 0 ]]; then
    warn "stdin is not a TTY — cannot prompt for medium_model interactively"
    return 1
  fi

  # ── 6. Build and display the menu ────────────────────────────────────────────
  local -a options=()
  local -a labels=()

  if [[ -n "${intermediate_model}" ]]; then
    options+=("${intermediate_model}")
    labels+=("recommended")
  fi
  if [[ -n "${main_model}" ]]; then
    options+=("${main_model}")
    labels+=("main model")
  fi
  if [[ -n "${small_model}" ]]; then
    options+=("${small_model}")
    labels+=("small model")
  fi

  echo -e "\n  ${TEXT_YELLOW}?${TEXT_CLEAR}  Select medium model for ${TEXT_BOLD}${project_name}${TEXT_CLEAR}:" >&2
  local i
  for i in "${!options[@]}"; do
    local num=$(( i + 1 ))
    echo -e "    ${TEXT_DIM}${num})${TEXT_CLEAR} ${options[${i}]} ${TEXT_DIM}(${labels[${i}]})${TEXT_CLEAR}" >&2
  done
  echo -e "    ${TEXT_DIM}c)${TEXT_CLEAR} Custom — type your own" >&2
  echo "" >&2

  # ── 7. Read user choice ───────────────────────────────────────────────────────
  local chosen=""
  while [[ -z "${chosen}" ]]; do
    ask "Your choice [1-${#options[@]}/c]:" >&2
    local reply
    read -r reply </dev/tty
    reply="${reply,,}"  # lowercase

    if [[ "${reply}" == "c" ]]; then
      ask "Enter model name:" >&2
      read -r chosen </dev/tty
      chosen="${chosen// /}"  # strip spaces
      if [[ -z "${chosen}" ]]; then
        warn "Empty input — please try again." >&2
        chosen=""
      fi
    elif [[ "${reply}" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= ${#options[@]} )); then
      chosen="${options[$(( reply - 1 ))]}"
    else
      warn "Invalid choice — please enter a number between 1 and ${#options[@]}, or 'c'." >&2
    fi
  done

  # ── 8. Persist and return ─────────────────────────────────────────────────────
  config.write_ini "${ini_file}" "medium_model" "${chosen}"
  log "medium_model = ${chosen} written to telamon.jsonc" >&2
  echo "${chosen}"
}

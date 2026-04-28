#!/usr/bin/env bash
# =============================================================================
# bin/submodule.sh
# Manage personal git repo clones configured in Telamon's .env.
#
# Usage:
#   telamon submodule add <url>
#   telamon submodule remove <url>
#   telamon submodule list
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_PATH="${TELAMON_ROOT}/src/tools"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"
export TOOLS_PATH FUNCTIONS_PATH TELAMON_ROOT

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

ENV_FILE="${TELAMON_ROOT}/.env"

BUILTIN_REPOS=(
  "https://github.com/addyosmani/agent-skills.git"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

# _derive_path <url>
# Converts a git URL to a vendor/<org>/<repo> path.
# Handles HTTPS:  https://github.com/org/repo.git
# Handles SSH:    git@github.com:org/repo.git
_derive_path() {
  local url="${1%/}"          # strip trailing slash
  url="${url%.git}"           # strip .git suffix

  local org_repo
  if [[ "${url}" == git@* ]]; then
    # SSH: git@github.com:org/repo  →  org/repo
    org_repo="${url##*:}"
  else
    # HTTPS: https://github.com/org/repo  →  last two segments
    local path_part="${url#*://}"   # strip scheme
    path_part="${path_part#*/}"     # strip host
    # take last two segments
    local repo; repo="$(basename "${path_part}")"
    local org;  org="$(basename "$(dirname "${path_part}")")"
    org_repo="${org}/${repo}"
  fi

  echo "vendor/${org_repo}"
}

# _read_submodules
# Prints each configured URL on its own line (empty output if none).
_read_submodules() {
  local raw
  raw="$(grep -s '^TELAMON_SUBMODULES=' "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d "\"'" || true)"
  [[ -z "${raw}" ]] && return 0
  # split on commas, print one per line, skip blanks
  IFS=',' read -ra _urls <<< "${raw}"
  for u in "${_urls[@]}"; do
    u="${u// /}"   # trim spaces
    [[ -n "${u}" ]] && echo "${u}"
  done
}

# _write_submodules <url> [<url> ...]
# Writes the TELAMON_SUBMODULES line to .env (creates file if absent).
_write_submodules() {
  local -a urls=("$@")
  local joined
  joined="$(IFS=','; echo "${urls[*]}")"

  # Ensure .env exists
  [[ -f "${ENV_FILE}" ]] || touch "${ENV_FILE}"

  if grep -q '^TELAMON_SUBMODULES=' "${ENV_FILE}" 2>/dev/null; then
    # Replace existing line (portable sed -i)
    sed -i.bak "s|^TELAMON_SUBMODULES=.*|TELAMON_SUBMODULES=${joined}|" "${ENV_FILE}"
    rm -f "${ENV_FILE}.bak"
  else
    echo "TELAMON_SUBMODULES=${joined}" >> "${ENV_FILE}"
  fi
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd_add() {
  local url="${1:-}"
  if [[ -z "${url}" ]]; then
    echo "Error: 'telamon submodule add' requires a URL" >&2
    echo >&2
    _usage >&2
    exit 1
  fi

  header "Submodule add"

  # Read existing list
  local -a existing=()
  while IFS= read -r u; do
    existing+=("${u}")
  done < <(_read_submodules)

  # Check for duplicate
  for u in "${existing[@]+"${existing[@]}"}"; do
    if [[ "${u}" == "${url}" ]]; then
      skip "already registered: ${url}"
      return 0
    fi
  done

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

  # Register in .env
  step "Registering in .env ..."
  existing+=("${url}")
  _write_submodules "${existing[@]}"
  log "Registered: ${url}"
}

cmd_remove() {
  local url="${1:-}"
  if [[ -z "${url}" ]]; then
    echo "Error: 'telamon submodule remove' requires a URL" >&2
    echo >&2
    _usage >&2
    exit 1
  fi

  header "Submodule remove"

  # Read existing list
  local -a existing=()
  while IFS= read -r u; do
    existing+=("${u}")
  done < <(_read_submodules)

  # Build new list without the target URL
  local -a updated=()
  local found=0
  for u in "${existing[@]+"${existing[@]}"}"; do
    if [[ "${u}" == "${url}" ]]; then
      found=1
    else
      updated+=("${u}")
    fi
  done

  if [[ "${found}" -eq 0 ]]; then
    warn "URL not found in TELAMON_SUBMODULES: ${url}"
  else
    step "Removing from .env ..."
    _write_submodules "${updated[@]+"${updated[@]}"}"
    log "Unregistered: ${url}"
  fi

  # Remove directory if it exists
  local dest="${TELAMON_ROOT}/$(_derive_path "${url}")"
  if [[ -d "${dest}" ]]; then
    step "Removing directory ${dest} ..."
    rm -rf "${dest}"
    log "Directory removed"
  else
    skip "directory not found: ${dest}"
  fi
}

cmd_list() {
  header "User submodules (from .env)"

  local -a urls=()
  while IFS= read -r u; do
    urls+=("${u}")
  done < <(_read_submodules)

  if [[ "${#urls[@]}" -eq 0 ]]; then
    info "No user submodules configured. Use 'telamon submodule add <url>' to add one."
  else
    for u in "${urls[@]}"; do
      local path
      path="$(_derive_path "${u}")"
      local full="${TELAMON_ROOT}/${path}"
      if [[ -d "${full}/.git" ]]; then
        echo -e "  ${TEXT_GREEN}✔${TEXT_CLEAR}  ${path}  ${TEXT_DIM}(${u})${TEXT_CLEAR}"
      else
        echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  ${path}  ${TEXT_DIM}(${u}) — not cloned${TEXT_CLEAR}"
      fi
    done
  fi

  header "Built-in vendor repos"
  for _burl in "${BUILTIN_REPOS[@]}"; do
    local bpath
    bpath="$(_derive_path "${_burl}")"
    local bfull="${TELAMON_ROOT}/${bpath}"
    if [[ -d "${bfull}/.git" ]]; then
      echo -e "  ${TEXT_GREEN}✔${TEXT_CLEAR}  ${bpath}  ${TEXT_DIM}(${_burl})${TEXT_CLEAR}"
    else
      echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  ${bpath}  ${TEXT_DIM}(${_burl}) — not cloned${TEXT_CLEAR}"
    fi
  done
}

_usage() {
  cat <<'EOF'
Usage: telamon submodule <subcommand> [args]

Subcommands:
  add <url>    Clone a git repo into vendor/ and register in .env
  remove <url> Remove a registered submodule from .env and disk
  list         Show all registered submodules with clone status
EOF
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

SUBCMD="${1:-}"
shift || true

case "${SUBCMD}" in
  add)    cmd_add    "$@" ;;
  remove) cmd_remove "$@" ;;
  list)   cmd_list        ;;
  help|"") _usage ;;
  *) echo "Error: unknown submodule subcommand '${SUBCMD}'" >&2; echo >&2; _usage >&2; exit 1 ;;
esac

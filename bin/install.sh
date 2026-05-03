#!/usr/bin/env bash
# =============================================================================
# bin/install.sh
# Idempotent installer for the full AI coding stack.
# Supports: macOS (Apple Silicon + Intel) and Linux Mint / Ubuntu / Debian.
# Safe to re-run at any time.
#
# Tools installed:
#   Homebrew / Linuxbrew       — package manager
#   Docker                     — container runtime
#   Ollama + nomic-embed-text  — local embeddings
#   opencode                   — AI coding agent
#   Graphify                   — codebase knowledge graph
#   opencode-codebase-index    — semantic codebase search (MCP)
#   Repomix                    — pack directories into compressed LLM context
#   promptfoo                  — agent evaluation framework (via npx)
#   RTK                        — token compression proxy
#
# Usage:
#   bin/install.sh                  # full install (interactive)
#   bin/install.sh --pre-docker     # phase 1 only: package managers + docker
#   bin/install.sh --post-docker    # phase 2 only: all tools that need containers
#
# Lifecycle:
#   make install  — runs this script (full install + boots services)
#   make up       — boots services only (no installation)
#   make update   — upgrades tools; installs any that are missing
# =============================================================================

set -euo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
# bin/ lives one level above src/tools/
TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_PATH="${TELAMON_ROOT}/src/tools"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"
export TOOLS_PATH FUNCTIONS_PATH

# ── Load shared functions ─────────────────────────────────────────────────────
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# ── Resolve Telamon root and storage paths ───────────────────────────────────────
STATE_DIR="${TELAMON_ROOT}/storage/state"
SECRETS_DIR="${TELAMON_ROOT}/storage/secrets"
export TELAMON_ROOT STATE_DIR SECRETS_DIR

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

# ── Ensure bun is installed ───────────────────────────────────────────────────
# bun — required for building opencode from source (patches)
_BUN_MIN="1.3.13"  # fallback; ideally read from .telamon.jsonc after clone
if ! command -v bun >/dev/null 2>&1; then
  step "Installing bun..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
fi
if command -v bun >/dev/null 2>&1; then
  log "bun found: $(bun --version)"
else
  warn "bun installation failed — opencode patches will not work"
fi

# ── Built-in vendor repos ────────────────────────────────────────────────────
# Clone mandatory vendor repos if not already present (plain clones, not submodules).
_derive_vendor_path() {
  local url="${1%/}"; url="${url%.git}"
  local org_repo
  if [[ "${url}" == git@* ]]; then org_repo="${url##*:}"
  else
    local p="${url#*://}"; p="${p#*/}"
    org_repo="$(basename "$(dirname "${p}")")/$(basename "${p}")"
  fi
  echo "vendor/${org_repo}"
}

BUILTIN_REPOS=(
  "https://github.com/addyosmani/agent-skills.git"
)

for _url in "${BUILTIN_REPOS[@]}"; do
  _dest="${TELAMON_ROOT}/$(_derive_vendor_path "${_url}")"
  if [[ ! -d "${_dest}/.git" ]]; then
    mkdir -p "$(dirname "${_dest}")"
    git clone --depth 1 "${_url}" "${_dest}" 2>/dev/null || true
  fi
done

# ── load_saved_inputs ──────────────────────────────────────────────────────────
# Sources the saved setup-inputs file and exports vars for child scripts.
# Non-interactive — used by --post-docker where inputs were already collected.
load_saved_inputs() {
  local dir_name
  dir_name="$(basename "$(pwd)")"

  if [[ -f "${STATE_DIR}/setup-inputs" ]]; then
    # shellcheck disable=SC1091
    source "${STATE_DIR}/setup-inputs" 2>/dev/null || true
  fi

  PROJECT_NAME="${SAVED_PROJECT_NAME:-${dir_name}}"

  export PROJECT_NAME

  # Selectively export optional-service flags for install module guards.
  # Do NOT use `set -a; source .env` — it would export OPENAI_API_KEY and other secrets globally.
  # Each install module reads its own secrets from .env via _read_env_value as needed.
  if [[ -f "${TELAMON_ROOT}/.env" ]]; then
    export LANGFUSE_ENABLED="$(grep -s '^LANGFUSE_ENABLED=' "${TELAMON_ROOT}/.env" | cut -d= -f2-)"
    export GRAPHITI_ENABLED="$(grep -s '^GRAPHITI_ENABLED=' "${TELAMON_ROOT}/.env" | cut -d= -f2-)"
  fi
}

# ── _read_ini_value ────────────────────────────────────────────────────────────
# Read a value from a simple INI file (key = value format).
# Usage: _read_ini_value <file> <key>
_read_ini_value() {
  local file="$1" key="$2"
  [[ -f "${file}" ]] || return 1
  local val
  val="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "${file}" | head -1 | sed 's/^[^=]*=[[:space:]]*//' | tr -d '[:space:]')"
  [[ -n "${val}" ]] || return 1
  echo "${val}"
}

# ── _read_env_value ────────────────────────────────────────────────────────────
# Read a value from a .env file (KEY=value format, strips quotes and whitespace).
# Usage: _read_env_value <file> <key>
_read_env_value() {
  local file="$1" key="$2"
  [[ -f "${file}" ]] || return 1
  local val
  val="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "${file}" | head -1 | sed "s/^[^=]*=[[:space:]]*//" | tr -d "\"' ")"
  [[ -n "${val}" ]] || return 1
  echo "${val}"
}

# ── collect_inputs ─────────────────────────────────────────────────────────────
collect_inputs() {
  header "Configuration"

  local dir_name
  dir_name="$(basename "$(pwd)")"

  # ── 1. Load saved state (lowest priority) ─────────────────────────────────
  local saved_project=""
  if [[ -f "${STATE_DIR}/setup-inputs" ]]; then
    # shellcheck disable=SC1091
    source "${STATE_DIR}/setup-inputs" 2>/dev/null || true
    saved_project="${SAVED_PROJECT_NAME:-}"
  fi

  # ── 2. Read .ai/telamon/telamon.jsonc (higher priority than saved state) ───────────────
  local ini_project=""
  ini_project="$(config.read_ini "${PWD}/.ai/telamon/telamon.jsonc" "project_name" 2>/dev/null || true)"

  # ── 3. Resolve defaults (ini > saved > fallback) ──────────────────────────
  local default_project
  default_project="${ini_project:-${saved_project:-${dir_name}}}"

  # ── 4. Prompt only for values we cannot resolve ────────────────────────────
  local prompted=0

  if [[ -n "${ini_project}" ]]; then
    info "Project name from .ai/telamon/telamon.jsonc: ${ini_project}"
    PROJECT_NAME="${ini_project}"
  else
    prompted=1
    ask "Project display name [${default_project}]:"
    read -r PROJECT_INPUT
    PROJECT_NAME="${PROJECT_INPUT:-${default_project}}"
  fi

  echo
  echo -e "  ${TEXT_BOLD}OS      :${TEXT_CLEAR} $(os.get_os) ($(os.get_arch))"
  echo -e "  ${TEXT_BOLD}Project :${TEXT_CLEAR} ${PROJECT_NAME}"
  echo

  # Only ask for confirmation when the user was prompted for at least one value
  if [[ "${prompted}" -eq 1 ]]; then
    ask "Proceed? (Y/n):"
    read -r CONFIRM
    [[ "${CONFIRM}" =~ ^[Nn] ]] && { info "Aborted."; exit 0; }
  fi

  mkdir -p "${STATE_DIR}"
  cat > "${STATE_DIR}/setup-inputs" <<ENV
SAVED_PROJECT_NAME="${PROJECT_NAME}"
ENV

  # Export for child scripts
  export PROJECT_NAME
}

# ── print_summary ──────────────────────────────────────────────────────────────
print_summary() {
  echo
  echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
  echo -e "${TEXT_BOLD}${TEXT_GREEN}  ✔  Done!${TEXT_CLEAR}"
  echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
  echo
  echo -e "  ${TEXT_BOLD}OS      :${TEXT_CLEAR} $(os.get_os) ($(os.get_arch))"
  echo -e "  ${TEXT_BOLD}Project :${TEXT_CLEAR} ${PROJECT_NAME}"
  echo

  echo -e "  ${TEXT_BOLD}Project init:${TEXT_CLEAR}"
  echo "    Graphify and codebase-index are built during 'bin/init.sh'."
  echo "    If either fails, the agent will self-initialize on first session."
  echo
  echo -e "  ${TEXT_BOLD}Verify:${TEXT_CLEAR}"
    echo "    bin/status.sh"
    echo "    graphify --version"
  echo
  echo -e "  ${TEXT_BOLD}Re-run in a new project:${TEXT_CLEAR}"
  echo "    cd ~/my-next-project && bash $(realpath "$0")"
  echo
  echo -e "  ${TEXT_BOLD}Docker services:${TEXT_CLEAR}"
  echo "    docker compose up -d"
  echo "    docker compose down"
  echo "    docker compose logs -f"
  echo
}

# ── Installation phases ────────────────────────────────────────────────────────
# Phase 1: tools that must exist BEFORE docker compose up (package managers,
#           docker itself). Called by `make install` before booting containers.
PRE_DOCKER_APPS=(homebrew docker)

# Phase 2: tools that require the containers to already be running (nomic-embed-text
#           model must be in Ollama). Called by `make install` after docker compose up.
POST_DOCKER_APPS=(python nodejs opencode codebase-index repomix promptfoo graphify rtk caveman qmd cli langfuse graphiti diff-context)

pre_docker() {
  for _app in "${PRE_DOCKER_APPS[@]}"; do
    timed_run "${_app}" bash "${TOOLS_PATH}/${_app}/install.sh"
  done
}

post_docker() {
  for _app in "${POST_DOCKER_APPS[@]}"; do
    timed_run "${_app}" bash "${TOOLS_PATH}/${_app}/install.sh"
  done
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  local total_start=${SECONDS}
  echo -e "\n${TEXT_BOLD}${TEXT_BLUE}"
  echo "  ══════════════════════════════════════════"
  echo "  Telamon Install"
  echo "  ══════════════════════════════════════════"
  echo -e "${TEXT_CLEAR}"

  collect_inputs
  pre_docker
  post_docker
  print_summary
  echo -e "  ${TEXT_DIM}⏱  Total install time: $(_fmt_duration $(( SECONDS - total_start )))${TEXT_CLEAR}"
  echo
}

case "${1:-}" in
  --pre-docker)  collect_inputs; pre_docker ;;
  --post-docker) load_saved_inputs; post_docker; print_summary; echo -e "  ${TEXT_DIM}⏱  Post-docker install time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"; echo ;;
  *)             main "$@" ;;
esac

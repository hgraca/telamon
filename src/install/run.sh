#!/usr/bin/env bash
# =============================================================================
# run.sh
# Idempotent installer for the full AI coding stack.
# Supports: macOS (Apple Silicon + Intel) and Linux Mint / Ubuntu / Debian.
# Safe to re-run at any time, in any project directory.
#
# Tools installed:
#   Homebrew / Linuxbrew       — package manager
#   Docker                     — container runtime
#   Ollama + nomic-embed-text  — local embeddings
#   opencode                   — AI coding agent
#   Ogham MCP + Postgres       — semantic agent memory
#   Graphify                   — codebase knowledge graph
#   opencode-codebase-index    — semantic codebase search (MCP)
#   cass                       — agent session history search
#   RTK                        — token compression proxy
#   Obsidian MCP (Docker)      — knowledge vault bridge
#
# Usage:
#   ./run.sh            # first run OR re-run in a new project
#   ./run.sh --status   # show what is/isn't installed
# =============================================================================

set -euo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
INSTALL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export INSTALL_PATH

# ── Load shared functions ─────────────────────────────────────────────────────
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# ── Resolve ADK root and storage paths ───────────────────────────────────────
ADK_ROOT="$(cd "${INSTALL_PATH}/../.." && pwd)"
STATE_DIR="${ADK_ROOT}/storage/state"
SECRETS_DIR="${ADK_ROOT}/storage/secrets"
export ADK_ROOT STATE_DIR SECRETS_DIR

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

# ── Status mode ───────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--status" ]]; then
  OS=$(os.get_os)
  echo -e "\n${TEXT_BOLD}AI Memory Stack — Status${TEXT_CLEAR}\n"
  _ok() { echo -e "  ${TEXT_GREEN}✔${TEXT_CLEAR}  $1"; }
  _no() { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  $1"; }

  if [[ "${OS}" == "macos" ]]; then
    command -v brew &>/dev/null && _ok "Homebrew"              || _no "Homebrew"
  else
    command -v brew &>/dev/null && _ok "Homebrew (Linuxbrew)"  || _no "Homebrew (Linuxbrew)"
  fi
  command -v docker   &>/dev/null                                          && _ok "Docker"                 || _no "Docker"
  docker info &>/dev/null 2>&1                                             && _ok "Docker running"         || _no "Docker not running"
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^ogham-postgres$"  && _ok "Postgres container"     || _no "Postgres container"
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^adk-ollama$"     && _ok "Ollama container"       || _no "Ollama container"
  docker exec adk-ollama ollama list 2>/dev/null | grep -q "nomic-embed-text" && _ok "nomic-embed-text"   || _no "nomic-embed-text"
  command -v uv       &>/dev/null                                          && _ok "uv"                     || _no "uv"
  command -v ogham    &>/dev/null                                          && _ok "Ogham"                  || _no "Ogham"
  command -v node     &>/dev/null                                          && _ok "Node.js"                || _no "Node.js"
  command -v graphify &>/dev/null                                          && _ok "Graphify"               || _no "Graphify"
  command -v cass     &>/dev/null                                          && _ok "cass"                   || _no "cass"
  command -v rtk      &>/dev/null                                          && _ok "RTK"                    || _no "RTK"
  command -v opencode &>/dev/null                                          && _ok "opencode"               || _no "opencode"
  [[ -f "${INSTALL_PATH}/../../storage/opencode.jsonc" ]]  && _ok "storage/opencode.jsonc"  || _no "storage/opencode.jsonc"
  [[ -d "${INSTALL_PATH}/../../storage/secrets" ]]         && _ok "storage/secrets/"         || _no "storage/secrets/ (run 'make up' to create)"
  [[ -d "${INSTALL_PATH}/../../storage/state" ]]           && _ok "storage/state/"           || _no "storage/state/ (run 'make up' to create)"
  [[ -d "${INSTALL_PATH}/../skills" ]]                     && _ok "ADK skills (src/skills)" || _no "ADK skills (src/skills)"
  ogham health &>/dev/null 2>&1                            && _ok "Ogham ↔ Postgres"       || _no "Ogham ↔ Postgres"
  echo
  exit 0
fi

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

  OGHAM_PROFILE="${SAVED_OGHAM_PROFILE:-${dir_name}}"
  PROJECT_NAME="${SAVED_PROJECT_NAME:-${dir_name}}"
  POSTGRES_PASSWORD="${SAVED_POSTGRES_PASSWORD:-ogham}"

  export OGHAM_PROFILE PROJECT_NAME POSTGRES_PASSWORD
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
  local saved_profile="" saved_pg_pass="" saved_project=""
  if [[ -f "${STATE_DIR}/setup-inputs" ]]; then
    # shellcheck disable=SC1091
    source "${STATE_DIR}/setup-inputs" 2>/dev/null || true
    saved_profile="${SAVED_OGHAM_PROFILE:-}"
    saved_project="${SAVED_PROJECT_NAME:-}"
    saved_pg_pass="${SAVED_POSTGRES_PASSWORD:-}"
  fi

  # ── 2. Read .ai/adk.ini (higher priority than saved state) ────────────────
  local ini_project=""
  ini_project="$(_read_ini_value "${PWD}/.ai/adk.ini" "project_name" 2>/dev/null || true)"

  # ── 3. Read .env for POSTGRES_PASSWORD (higher priority than saved state) ──
  local env_pg_pass=""
  env_pg_pass="$(_read_env_value "${PWD}/.env" "POSTGRES_PASSWORD" 2>/dev/null || true)"

  # ── 4. Resolve defaults (ini/env > saved > fallback) ──────────────────────
  local default_project default_profile default_pg_pass
  default_project="${ini_project:-${saved_project:-${dir_name}}}"
  default_profile="${ini_project:-${saved_profile:-${dir_name}}}"
  default_pg_pass="${env_pg_pass:-${saved_pg_pass:-ogham}}"

  # ── 5. Prompt only for values we cannot resolve ────────────────────────────
  if [[ -n "${ini_project}" ]]; then
    info "Project name from .ai/adk.ini: ${ini_project}"
    OGHAM_PROFILE="${ini_project}"
    PROJECT_NAME="${ini_project}"
  else
    ask "Ogham memory profile for this project [${default_profile}]:"
    read -r PROFILE_INPUT
    OGHAM_PROFILE="${PROFILE_INPUT:-${default_profile}}"

    ask "Project display name [${default_project}]:"
    read -r PROJECT_INPUT
    PROJECT_NAME="${PROJECT_INPUT:-${default_project}}"
  fi

  if [[ -n "${env_pg_pass}" && "${env_pg_pass}" != "REPLACE_WITH"* ]]; then
    info "Postgres password from .env (already set)"
    POSTGRES_PASSWORD="${env_pg_pass}"
  else
    ask "Postgres password [${default_pg_pass}]:"
    read -r -s PG_PASS_INPUT; echo
    POSTGRES_PASSWORD="${PG_PASS_INPUT:-${default_pg_pass}}"
  fi

  echo
  echo -e "  ${TEXT_BOLD}OS      :${TEXT_CLEAR} $(os.get_os) ($(os.get_arch))"
  echo -e "  ${TEXT_BOLD}Profile :${TEXT_CLEAR} ${OGHAM_PROFILE}"
  echo -e "  ${TEXT_BOLD}Project :${TEXT_CLEAR} ${PROJECT_NAME}"
  echo
  ask "Proceed? (Y/n):"
  read -r CONFIRM
  [[ "${CONFIRM}" =~ ^[Nn] ]] && { info "Aborted."; exit 0; }

  mkdir -p "${STATE_DIR}"
  cat > "${STATE_DIR}/setup-inputs" <<ENV
SAVED_OGHAM_PROFILE="${OGHAM_PROFILE}"
SAVED_PROJECT_NAME="${PROJECT_NAME}"
SAVED_POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
ENV

  # Export for child scripts
  export OGHAM_PROFILE PROJECT_NAME POSTGRES_PASSWORD
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
  echo -e "  ${TEXT_BOLD}Profile :${TEXT_CLEAR} ${OGHAM_PROFILE}"
  echo

  echo -e "  ${TEXT_BOLD}First session in each project:${TEXT_CLEAR}"
  echo "    The agent will self-initialize Graphify and codebase-index"
  echo "    automatically on first use — no manual steps needed."
  echo
  echo -e "  ${TEXT_BOLD}Verify:${TEXT_CLEAR}"
  echo "    ./run.sh --status"
  echo "    ogham health"
  echo "    ogham store \"test: setup complete\""
  echo "    cass --version"
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
#           docker itself). Called by `make up` before booting containers.
pre_docker() {
  bash "${INSTALL_PATH}/homebrew/install.sh"
  bash "${INSTALL_PATH}/docker/install.sh"
}

# Phase 2: tools that require the containers to already be running (ogham needs
#           Postgres; nomic-embed-text model must be in Ollama). Called by
#           `make up` after docker compose up.
post_docker() {
  bash "${INSTALL_PATH}/python/install.sh"
  bash "${INSTALL_PATH}/nodejs/install.sh"
  bash "${INSTALL_PATH}/opencode/install.sh"   # installs binary + creates base opencode.json
  bash "${INSTALL_PATH}/ogham/install.sh"       # installs binary + registers MCP block
  bash "${INSTALL_PATH}/codebase-index/install.sh"  # registers MCP block
  bash "${INSTALL_PATH}/obsidian/install.sh"    # registers MCP block
  bash "${INSTALL_PATH}/graphify/install.sh"
  bash "${INSTALL_PATH}/cass/install.sh"
  bash "${INSTALL_PATH}/rtk/install.sh"

  # ── Config files ─────────────────────────────────────────────────────────
  bash "${INSTALL_PATH}/graphify/setup.sh"          # per-project: hooks + skill
  bash "${INSTALL_PATH}/shell/write-env.sh"
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  echo -e "\n${TEXT_BOLD}${TEXT_BLUE}"
  echo "  ╔═════════════════════════════════════════════════╗"
  echo "  ║   AI Agentic Development Kit Installer          ║"
  echo "  ║   macOS · Linux Mint · Ubuntu · Debian          ║"
  echo "  ║   Ogham · Graphify · cass · codebase-index      ║"
  echo "  ║   Obsidian MCP · Ollama · Postgres · RTK        ║"
  echo "  ╚═════════════════════════════════════════════════╝"
  echo -e "${TEXT_CLEAR}"

  collect_inputs
  pre_docker
  post_docker
  print_summary
}

case "${1:-}" in
  --pre-docker)  collect_inputs; pre_docker ;;
  --post-docker) load_saved_inputs; post_docker; print_summary ;;
  --status)      ;; # handled above
  *)             main "$@" ;;
esac

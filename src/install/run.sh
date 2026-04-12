#!/usr/bin/env bash
# =============================================================================
# run.sh
# Idempotent installer for the full PHP AI coding stack.
# Supports: macOS (Apple Silicon + Intel) and Linux Mint / Ubuntu / Debian.
# Safe to re-run at any time, in any project directory.
#
# Tools installed:
#   Homebrew / Linuxbrew       — package manager
#   Docker                     — container runtime
#   Ollama + nomic-embed-text  — local embeddings
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

# ── State directory ───────────────────────────────────────────────────────────
STATE_DIR="$HOME/.config/ogham"
export STATE_DIR

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
  docker ps 2>/dev/null | grep -q "ogham-postgres"                         && _ok "Postgres container"     || _no "Postgres container"
  docker ps 2>/dev/null | grep -q "adk-ollama"                             && _ok "Ollama container"       || _no "Ollama container"
  docker exec adk-ollama ollama list 2>/dev/null | grep -q "nomic-embed-text" && _ok "nomic-embed-text"   || _no "nomic-embed-text"
  docker ps 2>/dev/null | grep -q "obsidian-mcp"                           && _ok "Obsidian MCP container" || _no "Obsidian MCP container"
  command -v uv       &>/dev/null                                          && _ok "uv"                     || _no "uv"
  command -v ogham    &>/dev/null                                          && _ok "Ogham"                  || _no "Ogham"
  command -v node     &>/dev/null                                          && _ok "Node.js"                || _no "Node.js"
  command -v graphify &>/dev/null                                          && _ok "Graphify"               || _no "Graphify"
  command -v cass     &>/dev/null                                          && _ok "cass"                   || _no "cass"
  command -v rtk      &>/dev/null                                          && _ok "RTK"                    || _no "RTK"
  [[ -f "$HOME/.config/opencode/opencode.json" ]]          && _ok "OpenCode config"        || _no "OpenCode config"
  [[ -f "$HOME/.config/opencode/AGENTS.md" ]]              && _ok "Global AGENTS.md"       || _no "Global AGENTS.md"
  [[ -f "$HOME/.config/opencode/skills/memory-stack/SKILL.md" ]]   && _ok "memory-stack skill"   || _no "memory-stack skill"
  [[ -f "$HOME/.config/opencode/skills/obsidian-vault/SKILL.md" ]] && _ok "obsidian-vault skill"  || _no "obsidian-vault skill"
  [[ -f "AGENTS.md" ]]                                     && _ok "Project AGENTS.md ($(pwd))" \
                                                           || _no "Project AGENTS.md ($(pwd))"
  ogham health &>/dev/null 2>&1                            && _ok "Ogham ↔ Postgres"       || _no "Ogham ↔ Postgres"
  echo
  exit 0
fi

# ── collect_inputs ─────────────────────────────────────────────────────────────
collect_inputs() {
  header "Configuration"

  local saved_profile="" saved_pg_pass="" saved_obsidian_key=""
  if [[ -f "${STATE_DIR}/setup-inputs" ]]; then
    # shellcheck disable=SC1091
    source "${STATE_DIR}/setup-inputs" 2>/dev/null || true
    saved_profile="${SAVED_OGHAM_PROFILE:-}"
    saved_pg_pass="${SAVED_POSTGRES_PASSWORD:-}"
    saved_obsidian_key="${SAVED_OBSIDIAN_KEY:-}"
  fi

  local dir_name
  dir_name="$(basename "$(pwd)")"

  ask "Ogham memory profile for this project [${saved_profile:-$dir_name}]:"
  read -r PROFILE_INPUT
  OGHAM_PROFILE="${PROFILE_INPUT:-${saved_profile:-$dir_name}}"

  ask "Project display name [${dir_name}]:"
  read -r PROJECT_INPUT
  PROJECT_NAME="${PROJECT_INPUT:-$dir_name}"

  ask "Postgres password [${saved_pg_pass:-ogham}]:"
  read -r -s PG_PASS_INPUT; echo
  POSTGRES_PASSWORD="${PG_PASS_INPUT:-${saved_pg_pass:-ogham}}"

  ask "Obsidian Local REST API key (Enter to keep existing / skip):"
  read -r -s OBSIDIAN_KEY_INPUT; echo
  if [[ -n "${OBSIDIAN_KEY_INPUT}" ]]; then
    OBSIDIAN_API_KEY="${OBSIDIAN_KEY_INPUT}"
  else
    OBSIDIAN_API_KEY="${saved_obsidian_key:-REPLACE_WITH_OBSIDIAN_API_KEY}"
  fi

  echo
  echo -e "  ${TEXT_BOLD}OS      :${TEXT_CLEAR} $(os.get_os) ($(os.get_arch))"
  echo -e "  ${TEXT_BOLD}Profile :${TEXT_CLEAR} ${OGHAM_PROFILE}"
  echo -e "  ${TEXT_BOLD}Project :${TEXT_CLEAR} ${PROJECT_NAME}"
  echo -e "  ${TEXT_BOLD}Obs key :${TEXT_CLEAR} ${OBSIDIAN_API_KEY:0:6}…"
  echo
  ask "Proceed? (Y/n):"
  read -r CONFIRM
  [[ "${CONFIRM}" =~ ^[Nn] ]] && { info "Aborted."; exit 0; }

  mkdir -p "${STATE_DIR}"
  cat > "${STATE_DIR}/setup-inputs" <<ENV
SAVED_OGHAM_PROFILE="${OGHAM_PROFILE}"
SAVED_POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
SAVED_OBSIDIAN_KEY="${OBSIDIAN_API_KEY}"
ENV

  # Export for child scripts
  export OGHAM_PROFILE PROJECT_NAME POSTGRES_PASSWORD OBSIDIAN_API_KEY
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
  echo -e "  ${TEXT_BOLD}AGENTS.md:${TEXT_CLEAR} $(pwd)/AGENTS.md"
  echo

  if [[ "${OBSIDIAN_API_KEY}" == "REPLACE_WITH_OBSIDIAN_API_KEY" ]]; then
    echo -e "  ${TEXT_BOLD}${TEXT_YELLOW}Still needed — Obsidian API key:${TEXT_CLEAR}"
    echo "    1. Install Obsidian manually from obsidian.md"
    echo "    2. Settings → Community Plugins → enable 'Local REST API'"
    echo "    3. Copy the API key from plugin settings"
    echo "    4. Re-run this script and paste the key when prompted"
    echo
  fi

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

  # ── Tool installation ──────────────────────────────────────────────────────
  bash "${INSTALL_PATH}/homebrew/install.sh"
  bash "${INSTALL_PATH}/docker/install.sh"
  bash "${INSTALL_PATH}/python/install.sh"
  bash "${INSTALL_PATH}/nodejs/install.sh"
  bash "${INSTALL_PATH}/ogham/install.sh"
  bash "${INSTALL_PATH}/graphify/install.sh"
  bash "${INSTALL_PATH}/cass/install.sh"
  bash "${INSTALL_PATH}/rtk/install.sh"

  # ── Post-compose service configuration ────────────────────────────────────
  # Schema is applied automatically by postgres via docker-entrypoint-initdb.d.
  # nomic-embed-text is pulled automatically by the ollama-init compose service.
  bash "${INSTALL_PATH}/ogham/init.sh"
  bash "${INSTALL_PATH}/cass/init.sh"
  bash "${INSTALL_PATH}/ogham/enable-reranking.sh"

  # ── Config files ───────────────────────────────────────────────────────────
  bash "${INSTALL_PATH}/opencode/write-config.sh"
  bash "${INSTALL_PATH}/opencode/write-codebase-index-config.sh"
  bash "${INSTALL_PATH}/graphify/setup.sh"          # per-project: hooks + skill
  bash "${INSTALL_PATH}/opencode/write-global-agents.sh"
  bash "${INSTALL_PATH}/opencode/write-project-agents.sh"  # always runs
  bash "${INSTALL_PATH}/shell/write-env.sh"

  print_summary
}

main "$@"

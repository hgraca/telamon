#!/usr/bin/env bash
# =============================================================================
# bin/status.sh
# Show installation status of all ADK tools and services.
#
# Usage:
#   bin/status.sh
#   make status
# =============================================================================

set -euo pipefail

ADK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${ADK_ROOT}/src/install"
export INSTALL_PATH ADK_ROOT

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

OS=$(os.get_os)
echo
_ok() { echo -e "  ${TEXT_GREEN}✔${TEXT_CLEAR}  $1"; }
_no() { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  $1"; }

if [[ "${OS}" == "macos" ]]; then
  command -v brew &>/dev/null && _ok "Homebrew"             || _no "Homebrew"
else
  command -v brew &>/dev/null && _ok "Homebrew (Linuxbrew)" || _no "Homebrew (Linuxbrew)"
fi
command -v docker &>/dev/null                                              && _ok "Docker"             || _no "Docker"
docker info &>/dev/null 2>&1                                               && _ok "Docker running"     || _no "Docker not running"
docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^ogham-postgres$"  && _ok "Postgres container" || _no "Postgres container"
docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^adk-ollama$"      && _ok "Ollama container"   || _no "Ollama container"
docker exec adk-ollama ollama list 2>/dev/null | grep -q "nomic-embed-text" && _ok "nomic-embed-text" || _no "nomic-embed-text"
command -v uv       &>/dev/null && _ok "uv"       || _no "uv"
command -v ogham    &>/dev/null && _ok "Ogham"    || _no "Ogham"
command -v node     &>/dev/null && _ok "Node.js"  || _no "Node.js"
command -v graphify &>/dev/null && _ok "Graphify" || _no "Graphify"
command -v cass     &>/dev/null && _ok "cass"     || _no "cass"
command -v rtk      &>/dev/null && _ok "RTK"      || _no "RTK"
command -v opencode &>/dev/null && _ok "opencode" || _no "opencode"
[[ -f "${ADK_ROOT}/storage/opencode.jsonc" ]] && _ok "storage/opencode.jsonc" || _no "storage/opencode.jsonc"
[[ -d "${ADK_ROOT}/storage/secrets" ]]        && _ok "storage/secrets/"        || _no "storage/secrets/ (run 'make up' to create)"
[[ -d "${ADK_ROOT}/storage/state" ]]          && _ok "storage/state/"          || _no "storage/state/ (run 'make up' to create)"
[[ -d "${ADK_ROOT}/src/skills" ]]             && _ok "ADK skills (src/skills)" || _no "ADK skills (src/skills)"
ogham health &>/dev/null 2>&1                 && _ok "Ogham ↔ Postgres"        || _no "Ogham ↔ Postgres"
echo

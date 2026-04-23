#!/usr/bin/env bash
# =============================================================================
# bin/uninstall.sh
# Completely remove Telamon from the system.
#
# Usage:
#   bin/uninstall.sh
#
# What it does:
#   1. Confirm with user (destructive!)
#   2. docker compose down -v --remove-orphans
#   3. Remove docker volume data dirs from storage/
#   4. Remove ALL scheduled jobs (all graphify-update-* timers)
#   5. Uninstall tools: ogham-mcp, graphifyy, qmd, opencode-ai
#   6. Remove ~/.ogham/config.env
#   7. Remove shell RC modifications (the telamon block)
#   8. Remove ALL storage/ contents
#   9. Remove Telamon root directory
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${TELAMON_ROOT}/src/install"

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

export TELAMON_ROOT INSTALL_PATH

header "Telamon Uninstall"

echo
warn "This will permanently remove Telamon and all its data from this system."
warn "This includes: Docker volumes, scheduled jobs, installed tools, storage/, and shell RC entries."
warn "This action CANNOT be undone."
echo

# Discover initialized projects via graphify storage markers
INIT_PROJECTS=""
INIT_COUNT=0
while IFS= read -r ppath_file; do
  if [[ -f "${ppath_file}" ]]; then
    INIT_PROJECTS="${INIT_PROJECTS}$(cat "${ppath_file}")"$'\n'
    INIT_COUNT=$((INIT_COUNT + 1))
  fi
done < <(find "${TELAMON_ROOT}/storage/graphify" -name ".project-path" 2>/dev/null || true)

if [[ ${INIT_COUNT} -gt 0 ]]; then
  warn "These projects have Telamon wiring that will become dangling symlinks:"
  while IFS= read -r p; do
    [[ -z "${p}" ]] && continue
    echo "    - ${p}"
  done <<< "${INIT_PROJECTS}"
  info "Run 'make reset PROJ=<path>' for each project first, or clean up manually after uninstall."
  echo
fi

ask "Type 'yes' to confirm uninstall:"
read -r CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  info "Aborted."
  exit 0
fi
echo

# ── Track what was removed for summary ────────────────────────────────────────
REMOVED=()

# ── 1. Docker compose down -v ─────────────────────────────────────────────────
header "Stopping Docker services"
step "Running docker compose down -v --remove-orphans..."

# Detect compose profiles (same logic as Makefile) — use string, not array,
# because bash 3.2 (macOS default) errors on empty arrays with set -u.
COMPOSE_PROFILES=""
if grep -s '^LANGFUSE_ENABLED=true' "${TELAMON_ROOT}/.env" &>/dev/null; then
  COMPOSE_PROFILES="${COMPOSE_PROFILES} --profile langfuse"
fi
if grep -s '^GRAPHITI_ENABLED=true' "${TELAMON_ROOT}/.env" &>/dev/null; then
  COMPOSE_PROFILES="${COMPOSE_PROFILES} --profile graphiti"
fi

# shellcheck disable=SC2086
if docker compose ${COMPOSE_PROFILES} down -v --remove-orphans 2>/dev/null; then
  log "Docker containers and volumes removed"
  REMOVED+=("Docker containers + volumes")
else
  warn "docker compose down failed or docker not running — continuing"
fi

# ── 2. Remove docker volume data dirs ─────────────────────────────────────────
header "Removing Docker volume data"
DOCKER_DIRS=(pgdata ollama graphify langfuse-pgdata langfuse-clickhouse neo4j-data)
for dir in "${DOCKER_DIRS[@]}"; do
  path="${TELAMON_ROOT}/storage/${dir}"
  if [[ -d "${path}" ]]; then
    rm -rf "${path}"
    log "Removed storage/${dir}/"
    REMOVED+=("storage/${dir}/")
  else
    skip "storage/${dir}/ (not found)"
  fi
done

# ── 3. Remove ALL scheduled jobs ──────────────────────────────────────────────
header "Removing scheduled jobs"
OS="$(uname -s)"

# Remove all graphify-update-* timers
step "Removing all graphify-update-* timers..."
if [[ "${OS}" == "Linux" ]]; then
  UNIT_DIR="${HOME}/.config/systemd/user"
  # Find all graphify-update-*.timer files
  while IFS= read -r timer_file; do
    job_name="$(basename "${timer_file}" .timer)"
    project="${job_name#graphify-update-}"
    systemctl --user disable --now "${job_name}.timer" 2>/dev/null || true
    rm -f "${UNIT_DIR}/${job_name}.service" "${UNIT_DIR}/${job_name}.timer"
    log "Removed scheduled job: ${job_name}"
    REMOVED+=("${job_name} scheduled job")
  done < <(find "${UNIT_DIR}" -name "graphify-update-*.timer" 2>/dev/null || true)
  systemctl --user daemon-reload 2>/dev/null || true
elif [[ "${OS}" == "Darwin" ]]; then
  PLIST_DIR="${HOME}/Library/LaunchAgents"
  while IFS= read -r plist_file; do
    job_name="$(basename "${plist_file}" .plist)"
    launchctl bootout "gui/$(id -u)" "${plist_file}" 2>/dev/null || true
    rm -f "${plist_file}"
    log "Removed scheduled job: ${job_name}"
    REMOVED+=("${job_name} scheduled job")
  done < <(find "${PLIST_DIR}" -name "com.telamon.graphify-update-*.plist" 2>/dev/null || true)
fi

# ── 4. Uninstall tools ────────────────────────────────────────────────────────
header "Uninstalling tools"

_uninstall_uv_tool() {
  local tool="$1"
  step "Uninstalling ${tool} (uv tool)..."
  if command -v uv &>/dev/null; then
    if uv tool uninstall "${tool}" 2>/dev/null; then
      log "Uninstalled: ${tool}"
      REMOVED+=("${tool} (uv tool)")
    else
      skip "${tool} (not installed or already removed)"
    fi
  else
    warn "uv not found — skipping ${tool} uninstall"
  fi
}

_uninstall_npm_global() {
  local pkg="$1"
  step "Uninstalling ${pkg} (npm global)..."
  if command -v npm &>/dev/null; then
    if npm uninstall -g "${pkg}" 2>/dev/null; then
      log "Uninstalled: ${pkg}"
      REMOVED+=("${pkg} (npm global)")
    else
      skip "${pkg} (not installed or already removed)"
    fi
  else
    warn "npm not found — skipping ${pkg} uninstall"
  fi
}

_uninstall_brew() {
  local pkg="$1"
  step "Uninstalling ${pkg} (brew)..."
  if command -v brew &>/dev/null; then
    if brew uninstall "${pkg}" 2>/dev/null; then
      log "Uninstalled: ${pkg}"
      REMOVED+=("${pkg} (brew)")
    else
      skip "${pkg} (not installed or already removed)"
    fi
  else
    warn "brew not found — skipping ${pkg} uninstall"
  fi
}

_uninstall_uv_tool "ogham-mcp"
_uninstall_uv_tool "graphifyy"
_uninstall_npm_global "@tobilu/qmd"
_uninstall_npm_global "opencode-ai"

step "Removing homebrew tap: dicklesworthstone/tap (cass, legacy)..."
if command -v brew &>/dev/null; then
  if brew untap dicklesworthstone/tap 2>/dev/null; then
    log "Removed tap: dicklesworthstone/tap"
    REMOVED+=("dicklesworthstone/tap (brew tap)")
  else
    skip "dicklesworthstone/tap (not tapped or already removed)"
  fi
else
  warn "brew not found — skipping tap removal"
fi

# ── 5. Remove ogham config ────────────────────────────────────────────────────
header "Removing ogham config"
OGHAM_CONFIG="${HOME}/.ogham/config.env"
step "Removing ${OGHAM_CONFIG}..."
if [[ -f "${OGHAM_CONFIG}" ]]; then
  rm -f "${OGHAM_CONFIG}"
  log "Removed: ~/.ogham/config.env"
  REMOVED+=("~/.ogham/config.env")
  # Remove ~/.ogham/ if now empty
  if [[ -d "${HOME}/.ogham" ]] && [[ -z "$(ls -A "${HOME}/.ogham" 2>/dev/null)" ]]; then
    rmdir "${HOME}/.ogham"
    log "Removed empty dir: ~/.ogham/"
  fi
else
  skip "~/.ogham/config.env (not found)"
fi

# ── 6. Remove shell RC modifications ─────────────────────────────────────────
header "Removing shell RC modifications"

# Determine shell RC file (same logic as write-env.sh)
SHELL_RC="${HOME}/.zshrc"
if [[ "${SHELL:-}" == *"bash"* ]]; then
  SHELL_RC="${HOME}/.bashrc"
  [[ "$(uname -s)" == "Darwin" ]] && SHELL_RC="${HOME}/.bash_profile"
fi

AI_MARKER="# ai-memory-stack"
QMD_MARKER="# ai-qmd-wrapper"

_remove_shell_block() {
  local file="$1" marker="$2" label="$3"
  if [[ ! -f "${file}" ]]; then
    skip "${label} (${file} not found)"
    return
  fi
  if ! grep -q "${marker}" "${file}" 2>/dev/null; then
    skip "${label} (not found in ${file})"
    return
  fi
  # Use python3 to remove the block: from the marker line to the next blank line
  # after the block (handles multi-line blocks safely)
  python3 - "${file}" "${marker}" <<'PYEOF'
import sys, re
path, marker = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
# Remove from marker line through the end of the block (up to next blank line or EOF)
# Pattern: optional leading newline, marker line, everything until blank line or EOF
pattern = r'\n?' + re.escape(marker) + r'[^\n]*\n(?:(?!\n).*\n)*(?:(?!\n).*)?'
new_content = re.sub(pattern, '\n', content)
# Clean up multiple consecutive blank lines left behind
new_content = re.sub(r'\n{3,}', '\n\n', new_content)
with open(path, 'w') as f:
    f.write(new_content)
PYEOF
  log "Removed ${label} from ${file}"
  REMOVED+=("${label} from $(basename "${file}")")
}

step "Removing ai-memory-stack block from ${SHELL_RC}..."
_remove_shell_block "${SHELL_RC}" "${AI_MARKER}" "ai-memory-stack block"

step "Removing ai-qmd-wrapper block from ${SHELL_RC}..."
_remove_shell_block "${SHELL_RC}" "${QMD_MARKER}" "ai-qmd-wrapper block"

# ── 7. Remove CLI and desktop entry ──────────────────────────────────────────
header "Removing CLI and desktop entry"

CLI_SYMLINK="${HOME}/.local/bin/telamon"
step "Removing ~/.local/bin/telamon..."
if [[ -L "${CLI_SYMLINK}" ]]; then
  rm -f "${CLI_SYMLINK}"
  log "Removed ~/.local/bin/telamon"
  REMOVED+=("~/.local/bin/telamon")
else
  skip "~/.local/bin/telamon (not found)"
fi

OS="$(uname -s)"
if [[ "${OS}" == "Linux" ]]; then
  DESKTOP_FILE="${HOME}/.local/share/applications/telamon.desktop"
  step "Removing telamon.desktop..."
  if [[ -f "${DESKTOP_FILE}" ]]; then
    rm -f "${DESKTOP_FILE}"
    log "Removed ~/.local/share/applications/telamon.desktop"
    REMOVED+=("~/.local/share/applications/telamon.desktop")
    update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
  else
    skip "telamon.desktop (not found)"
  fi
elif [[ "${OS}" == "Darwin" ]]; then
  APP_DIR="${HOME}/Applications/Telamon.app"
  step "Removing Telamon.app..."
  if [[ -d "${APP_DIR}" ]]; then
    rm -rf "${APP_DIR}"
    log "Removed ~/Applications/Telamon.app"
    REMOVED+=("~/Applications/Telamon.app")
  else
    skip "Telamon.app (not found)"
  fi
fi

# ── 8. Remove ALL storage/ contents ──────────────────────────────────────────
header "Removing storage/"
step "Removing ${TELAMON_ROOT}/storage/..."
if [[ -d "${TELAMON_ROOT}/storage" ]]; then
  rm -rf "${TELAMON_ROOT}/storage"
  log "Removed storage/"
  REMOVED+=("storage/ (all data)")
else
  skip "storage/ (not found)"
fi

# ── 9. Summary ────────────────────────────────────────────────────────────────
echo
echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
echo -e "${TEXT_BOLD}${TEXT_GREEN}  ✔  Telamon uninstalled${TEXT_CLEAR}"
echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
echo
echo -e "  ${TEXT_BOLD}Removed:${TEXT_CLEAR}"
for item in "${REMOVED[@]}"; do
  echo "    ✔  ${item}"
done
echo "    ✔  ${TELAMON_ROOT}/ (Telamon repository)"
echo
echo -e "  ${TEXT_DIM}⏱  Total uninstall time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"
echo

# ── 10. Remove Telamon root directory ─────────────────────────────────────────
header "Removing Telamon"
step "Removing ${TELAMON_ROOT}..."
rm -rf "${TELAMON_ROOT}"

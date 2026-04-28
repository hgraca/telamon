#!/usr/bin/env bash
# =============================================================================
# src/tools/discord/install.sh
# Optional install module for the Discord bot (remote-opencode).
#
# Guarded by DISCORD_ENABLED=true in .env.
# Installs the remote-opencode npm package on the host.
# Configuration is managed by remote-opencode itself (~/.remote-opencode/config.json).
# =============================================================================

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export TOOLS_PATH FUNCTIONS_PATH

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Discord Bot (remote-opencode)"

# ── Guard: skip if explicitly disabled; prompt when unset ─────────────────────
if env.is_disabled DISCORD_ENABLED; then
  skip "Discord Bot (disabled)"
  exit 0
fi

ENV_FILE="${TELAMON_ROOT:?TELAMON_ROOT must be set}/.env"

# ── Migrate from old DISCORD_BRIDGE_ENABLED ─────────────────────────────────
_old_val="$(grep -s '^DISCORD_BRIDGE_ENABLED=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2- || true)"
if [[ -n "${_old_val}" ]]; then
  _new_val="$(grep -s '^DISCORD_ENABLED=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2- || true)"
  if [[ -z "${_new_val}" ]]; then
    # Migrate old value to new variable
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s|^DISCORD_BRIDGE_ENABLED=.*|DISCORD_ENABLED=${_old_val}|" "${ENV_FILE}"
    else
      sed -i "s|^DISCORD_BRIDGE_ENABLED=.*|DISCORD_ENABLED=${_old_val}|" "${ENV_FILE}"
    fi
    grep -q '^DISCORD_ENABLED=' "${ENV_FILE}" || echo "DISCORD_ENABLED=${_old_val}" >> "${ENV_FILE}"
    log "Migrated DISCORD_BRIDGE_ENABLED=${_old_val} → DISCORD_ENABLED=${_old_val}"
    export DISCORD_ENABLED="${_old_val}"
  fi
  # Remove old variables no longer needed by remote-opencode
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' '/^DISCORD_BRIDGE_ENABLED=/d' "${ENV_FILE}"
    sed -i '' '/^DISCORD_BOT_TOKEN=/d' "${ENV_FILE}"
    sed -i '' '/^DISCORD_ALLOWED_USER_IDS=/d' "${ENV_FILE}"
    sed -i '' '/^DISCORD_WORKSPACES_DIR=/d' "${ENV_FILE}"
  else
    sed -i '/^DISCORD_BRIDGE_ENABLED=/d' "${ENV_FILE}"
    sed -i '/^DISCORD_BOT_TOKEN=/d' "${ENV_FILE}"
    sed -i '/^DISCORD_ALLOWED_USER_IDS=/d' "${ENV_FILE}"
    sed -i '/^DISCORD_WORKSPACES_DIR=/d' "${ENV_FILE}"
  fi
  # Also remove the comment line about workspaces if present
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' '/^# Path to your development directory.*bridge container/d' "${ENV_FILE}"
  else
    sed -i '/^# Path to your development directory.*bridge container/d' "${ENV_FILE}"
  fi
fi

# When DISCORD_ENABLED is empty, ask the user whether to enable it.
if ! env.is_enabled DISCORD_ENABLED; then
  if [[ -t 0 ]]; then
    echo
    ask "Enable Discord integration? (Y/n):"
    read -r _discord_answer
    if [[ ! "${_discord_answer}" =~ ^[Nn]$ ]]; then
      if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s|^DISCORD_ENABLED=.*|DISCORD_ENABLED=true|" "${ENV_FILE}"
      else
        sed -i "s|^DISCORD_ENABLED=.*|DISCORD_ENABLED=true|" "${ENV_FILE}"
      fi
      grep -q '^DISCORD_ENABLED=' "${ENV_FILE}" || echo 'DISCORD_ENABLED=true' >> "${ENV_FILE}"
      log "DISCORD_ENABLED=true written to .env"
    else
      if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s|^DISCORD_ENABLED=.*|DISCORD_ENABLED=false|" "${ENV_FILE}"
      else
        sed -i "s|^DISCORD_ENABLED=.*|DISCORD_ENABLED=false|" "${ENV_FILE}"
      fi
      grep -q '^DISCORD_ENABLED=' "${ENV_FILE}" || echo 'DISCORD_ENABLED=false' >> "${ENV_FILE}"
      skip "Discord Bot (user chose not to enable)"
      exit 0
    fi
  else
    # Non-interactive: default to disabled
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s|^DISCORD_ENABLED=.*|DISCORD_ENABLED=false|" "${ENV_FILE}"
    else
      sed -i "s|^DISCORD_ENABLED=.*|DISCORD_ENABLED=false|" "${ENV_FILE}"
    fi
    grep -q '^DISCORD_ENABLED=' "${ENV_FILE}" || echo 'DISCORD_ENABLED=false' >> "${ENV_FILE}"
    skip "Discord Bot (non-interactive, defaulting to disabled)"
    exit 0
  fi
fi

# ── Check Node.js 22+ ─────────────────────────────────────────────────────────
step "Checking Node.js version..."
if ! command -v node >/dev/null 2>&1; then
  warn "Node.js is not installed. remote-opencode requires Node.js 22+."
  warn "Install Node.js 22+ and re-run install."
  exit 1
fi

_node_major="$(node --version | sed 's/v//' | cut -d. -f1)"
if [[ "${_node_major}" -lt 22 ]]; then
  warn "Node.js ${_node_major} is too old. remote-opencode requires Node.js 22+."
  warn "Upgrade Node.js and re-run install."
  exit 1
fi
log "Node.js v${_node_major} ✓"

# ── Install remote-opencode ───────────────────────────────────────────────────
step "Installing remote-opencode..."
npm install -g remote-opencode \
  && log "remote-opencode installed" \
  || { warn "npm install -g remote-opencode failed"; exit 1; }

# ── Check if already configured ──────────────────────────────────────────────
_config_file="${HOME}/.remote-opencode/config.json"
if [[ -f "${_config_file}" ]] && grep -q '"discordToken"' "${_config_file}" 2>/dev/null; then
  skip "remote-opencode already configured"
else
  echo
  echo -e "  ┌─────────────────────────────────────────────────────────────┐"
  echo -e "  │                                                             │"
  echo -e "  │   Run: remote-opencode setup                                │"
  echo -e "  │                                                             │"
  echo -e "  │   This interactive wizard will configure your Discord bot   │"
  echo -e "  │   token, client ID, guild ID, and allowed users.            │"
  echo -e "  │                                                             │"
  echo -e "  └─────────────────────────────────────────────────────────────┘"
  echo
fi

# ── Final message ─────────────────────────────────────────────────────────────
echo
log "Discord Bot (remote-opencode) is installed. Start with: make up"
echo

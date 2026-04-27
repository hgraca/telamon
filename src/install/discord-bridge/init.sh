#!/usr/bin/env bash
# =============================================================================
# src/install/discord-bridge/init.sh
# Per-project initialization for the Discord bridge.
#
# Configures discord_enabled, discord_forum_channel, and
# discord_forum_channel_id in .ai/telamon/telamon.jsonc.
#
# Expected env: PROJ, PROJECT_NAME, TELAMON_ROOT, INSTALL_PATH.
# =============================================================================

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export INSTALL_PATH

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Discord Bridge — per-project init"

# ── Guard: skip if not enabled ────────────────────────────────────────────────
env.is_enabled DISCORD_BRIDGE_ENABLED || { skip "Discord Bridge (disabled)"; exit 0; }

PROJ="${PROJ:?PROJ must be set}"
PROJECT_NAME="${PROJECT_NAME:?PROJECT_NAME must be set}"
JSONC_FILE="${PROJ}/.ai/telamon/telamon.jsonc"

# ── Read existing discord config ──────────────────────────────────────────────
existing_enabled="$(config.read_ini "${JSONC_FILE}" "discord_enabled" 2>/dev/null || true)"

if [[ -n "${existing_enabled}" ]]; then
  skip "Discord config already set (discord_enabled=${existing_enabled})"
  exit 0
fi

# ── Prompt or apply safe default ─────────────────────────────────────────────
if [[ -t 0 ]]; then
  echo
  ask "Enable Discord integration for this project? (y/N):"
  read -r answer

  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    # Prompt for forum channel name
    echo
    ask "Forum Channel name (default: ${PROJECT_NAME}):"
    read -r channel_name
    channel_name="${channel_name:-${PROJECT_NAME}}"

    echo
    echo "  Create a Forum Channel named '${channel_name}' in your Discord server."
    echo "  Then right-click the channel → 'Copy Channel ID' (requires Developer Mode)."
    echo

    channel_id=""
    while [[ -z "${channel_id}" ]]; do
      ask "Forum Channel ID:"
      read -r channel_id
    done

    step "Writing Discord config to telamon.jsonc..."
    config.write_ini "${JSONC_FILE}" "discord_enabled" "true"
    config.write_ini "${JSONC_FILE}" "discord_forum_channel" "${channel_name}"
    config.write_ini "${JSONC_FILE}" "discord_forum_channel_id" "${channel_id}"
    log "discord_enabled=true, discord_forum_channel=${channel_name}, discord_forum_channel_id=${channel_id}"
  else
    step "Writing Discord config to telamon.jsonc..."
    config.write_ini "${JSONC_FILE}" "discord_enabled" "false"
    log "discord_enabled=false"
  fi
else
  step "Non-interactive mode — writing safe default (discord_enabled=false)..."
  config.write_ini "${JSONC_FILE}" "discord_enabled" "false"
  log "discord_enabled=false"
fi

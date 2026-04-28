#!/usr/bin/env bash
# =============================================================================
# src/tools/discord/init.sh
# Discord Bot — per-project init.
#
# Configures discord_enabled in .ai/telamon/telamon.jsonc.
# Projects are registered in Discord via slash commands (/setpath, /use).
#
# Expected env: PROJ, PROJECT_NAME, TELAMON_ROOT, TOOLS_PATH.
# =============================================================================

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export TOOLS_PATH FUNCTIONS_PATH

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Discord Bot — per-project init"

# ── Guard: skip if explicitly disabled; prompt when unset ─────────────────────
if env.is_disabled DISCORD_ENABLED; then
  skip "Discord Bot (disabled)"
  exit 0
fi

if ! env.is_enabled DISCORD_ENABLED; then
  skip "Discord Bot (DISCORD_ENABLED not set — run global install first)"
  exit 0
fi

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
    step "Writing Discord config to telamon.jsonc..."
    config.write_ini "${JSONC_FILE}" "discord_enabled" "true"
    log "discord_enabled=true"

    echo
    echo "  Register this project in Discord:"
    echo "    /setpath alias:${PROJECT_NAME} path:${PROJ}"
    echo "  Then bind a channel:"
    echo "    /use alias:${PROJECT_NAME}"
    echo
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

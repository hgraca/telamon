#!/usr/bin/env bash
# =============================================================================
# src/install/discord-bridge/install.sh
# Optional install module for the Discord bridge (opencode-chat-bridge).
#
# Guarded by DISCORD_BRIDGE_ENABLED=true in .env.
# Prompts for DISCORD_BOT_TOKEN and DISCORD_ALLOWED_USER_IDS if not set.
# Writes tokens to .env (replacing placeholders) and storage/secrets/.
# =============================================================================

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SECRETS_DIR="${SECRETS_DIR:-$(cd "${INSTALL_PATH}/../.." && pwd)/storage/secrets}"
export INSTALL_PATH SECRETS_DIR

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Discord Bridge (opencode-chat-bridge)"

# ── Guard: skip if explicitly disabled; prompt when unset ─────────────────────
if env.is_disabled DISCORD_BRIDGE_ENABLED; then
  skip "Discord Bridge (disabled)"
  exit 0
fi

ENV_FILE="${TELAMON_ROOT:?TELAMON_ROOT must be set}/.env"

# When DISCORD_BRIDGE_ENABLED is empty, ask the user whether to enable it.
if ! env.is_enabled DISCORD_BRIDGE_ENABLED; then
  if [[ -t 0 ]]; then
    echo
    ask "Enable Discord integration? (y/N):"
    read -r _discord_answer
    if [[ "${_discord_answer}" =~ ^[Yy]$ ]]; then
      if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s|^DISCORD_BRIDGE_ENABLED=.*|DISCORD_BRIDGE_ENABLED=true|" "${ENV_FILE}"
      else
        sed -i "s|^DISCORD_BRIDGE_ENABLED=.*|DISCORD_BRIDGE_ENABLED=true|" "${ENV_FILE}"
      fi
      log "DISCORD_BRIDGE_ENABLED=true written to .env"
    else
      if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s|^DISCORD_BRIDGE_ENABLED=.*|DISCORD_BRIDGE_ENABLED=false|" "${ENV_FILE}"
      else
        sed -i "s|^DISCORD_BRIDGE_ENABLED=.*|DISCORD_BRIDGE_ENABLED=false|" "${ENV_FILE}"
      fi
      skip "Discord Bridge (user chose not to enable)"
      exit 0
    fi
  else
    # Non-interactive: default to disabled
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s|^DISCORD_BRIDGE_ENABLED=.*|DISCORD_BRIDGE_ENABLED=false|" "${ENV_FILE}"
    else
      sed -i "s|^DISCORD_BRIDGE_ENABLED=.*|DISCORD_BRIDGE_ENABLED=false|" "${ENV_FILE}"
    fi
    skip "Discord Bridge (non-interactive, defaulting to disabled)"
    exit 0
  fi
fi

# ── discord_bridge.write_env_var ──────────────────────────────────────────────
# Writes a value into .env (replacing placeholder) and storage/secrets/.
#
# Usage: discord_bridge.write_env_var <ENV_KEY> <SECRET_NAME> <VALUE>
discord_bridge.write_env_var() {
  local env_key="${1:?env_key is required}"
  local secret_name="${2:?secret_name is required}"
  local value="${3:?value is required}"

  if [[ -f "${ENV_FILE}" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s|^${env_key}=REPLACE_WITH.*|${env_key}=${value}|" "${ENV_FILE}"
    else
      sed -i "s|^${env_key}=REPLACE_WITH.*|${env_key}=${value}|" "${ENV_FILE}"
    fi
    log "${env_key} written to .env"
  else
    warn ".env not found — cannot write ${env_key}. Add manually: ${env_key}=${value}"
  fi

  secrets.write "${secret_name}" "${value}"
}

# ── discord_bridge.is_configured ─────────────────────────────────────────────
# Returns 0 if the env key is set and not a placeholder, 1 otherwise.
discord_bridge.is_configured() {
  local env_key="${1:?env_key is required}"
  local current_val
  current_val="$(grep -E "^[[:space:]]*${env_key}[[:space:]]*=" "${ENV_FILE}" 2>/dev/null \
    | head -1 | cut -d= -f2- | tr -d "\"' " || true)"
  [[ -n "${current_val}" && "${current_val}" != "REPLACE_WITH"* ]]
}

# ── Check / prompt for DISCORD_BOT_TOKEN ─────────────────────────────────────
if discord_bridge.is_configured "DISCORD_BOT_TOKEN"; then
  skip "DISCORD_BOT_TOKEN (already set in .env)"
  secrets.write "discord-bot-token" \
    "$(grep -E "^[[:space:]]*DISCORD_BOT_TOKEN[[:space:]]*=" "${ENV_FILE}" \
      | head -1 | cut -d= -f2- | tr -d "\"' ")"
elif [[ -t 0 ]]; then
  echo
  echo -e "  ${TEXT_BOLD}Discord Bot Setup${TEXT_CLEAR}"
  echo
  echo "  You need a Discord Application and Bot to use the Discord bridge."
  echo "  Follow these steps:"
  echo
  echo "  1. Sign up at https://discord.com (or log in if you already have an account)."
  echo "  2. Create a private server: click '+' in the left sidebar → 'Create My Own'"
  echo "     → 'For me and my friends' → give it a name."
  echo "  3. In your server, go to Settings (gear icon) → enable 'Developer Mode' under 'Advanced'."
  echo "  4. Go to https://discord.com/developers/applications"
  echo "  5. Click 'New Application' and give it a name."
  echo "  6. Go to 'Bot' in the left sidebar."
  echo "  7. Make sure 'Public Bot' is DISABLED (off) — this keeps the bot private."
  echo "     NOTE: Using a private Discord server is recommended for security."
  echo "  8. Under 'Privileged Gateway Intents', enable MESSAGE CONTENT INTENT."
  echo "  9. Click 'Reset Token' and copy the bot token."
  echo " 10. Go to 'General Information' in the left sidebar and copy the APPLICATION ID."
  echo " 11. Open this URL in your browser (replace YOUR_APP_ID with the Application ID):"
  echo "     https://discord.com/oauth2/authorize?client_id=YOUR_APP_ID&scope=bot&permissions=326417583104"
  echo "     (Permissions: Send Messages, Read Message History, Create Public Threads,"
  echo "      Send Messages in Threads, Manage Threads, View Channels.)"
  echo " 12. Select your private Discord server and authorize the bot."
  echo

  bot_token=""
  while [[ -z "${bot_token}" ]]; do
    ask "DISCORD_BOT_TOKEN (paste your bot token):"
    read -r bot_token
  done

  discord_bridge.write_env_var "DISCORD_BOT_TOKEN" "discord-bot-token" "${bot_token}"
else
  warn "DISCORD_BOT_TOKEN not set and stdin is not a TTY."
  warn "Set DISCORD_BOT_TOKEN in .env manually before starting the Discord bridge."
fi

# ── Check / prompt for DISCORD_ALLOWED_USER_IDS ──────────────────────────────
if discord_bridge.is_configured "DISCORD_ALLOWED_USER_IDS"; then
  skip "DISCORD_ALLOWED_USER_IDS (already set in .env)"
  secrets.write "discord-allowed-user-ids" \
    "$(grep -E "^[[:space:]]*DISCORD_ALLOWED_USER_IDS[[:space:]]*=" "${ENV_FILE}" \
      | head -1 | cut -d= -f2- | tr -d "\"' ")"
elif [[ -t 0 ]]; then
  echo
  echo "  To find your Discord user ID:"
  echo "  1. In Discord, go to Settings → Advanced → enable Developer Mode."
  echo "  2. Right-click your username and select 'Copy User ID'."
  echo "  Multiple IDs can be separated by commas."
  echo

  allowed_ids=""
  while [[ -z "${allowed_ids}" ]]; do
    ask "DISCORD_ALLOWED_USER_IDS (comma-separated Discord user IDs):"
    read -r allowed_ids
  done

  discord_bridge.write_env_var "DISCORD_ALLOWED_USER_IDS" "discord-allowed-user-ids" "${allowed_ids}"
else
  warn "DISCORD_ALLOWED_USER_IDS not set and stdin is not a TTY."
  warn "Set DISCORD_ALLOWED_USER_IDS in .env manually before starting the Discord bridge."
fi

# ── Print usage instructions ──────────────────────────────────────────────────
echo
echo -e "  ${TEXT_BOLD}Discord Bridge is enabled.${TEXT_CLEAR}"
echo
echo -e "  ${TEXT_BOLD}Container:${TEXT_CLEAR}  opencode-bridge (image: lbecchi/opencode-chat-bridge)"
echo
echo -e "  ${TEXT_BOLD}Usage:${TEXT_CLEAR}"
echo "    The bot will listen for messages in your Discord server."
echo "    Only users listed in DISCORD_ALLOWED_USER_IDS can interact with it."
echo "    Per-project forum channel configuration is done via 'bin/init.sh'."
echo

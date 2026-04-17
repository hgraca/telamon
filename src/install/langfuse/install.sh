#!/usr/bin/env bash
# =============================================================================
# src/install/langfuse/install.sh
# Optional install module for Langfuse (LLM observability).
#
# Guarded by LANGFUSE_ENABLED=true in .env.
# Generates LANGFUSE_SECRET and LANGFUSE_SALT if not already set.
# Prints connection instructions — no MCP registration (Langfuse is a web UI).
# =============================================================================

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SECRETS_DIR="${SECRETS_DIR:-$(cd "${INSTALL_PATH}/../.." && pwd)/storage/secrets}"
export INSTALL_PATH SECRETS_DIR

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Langfuse (LLM observability)"

# ── Guard: skip if not enabled ────────────────────────────────────────────────
env.is_enabled LANGFUSE_ENABLED || { skip "Langfuse (disabled)"; exit 0; }

ENV_FILE="${TELAMON_ROOT:?TELAMON_ROOT must be set}/.env"

# ── langfuse.generate_secret ──────────────────────────────────────────────────
# Generates a random hex secret and writes it into .env (replacing placeholder).
# Also writes to storage/secrets/ via secrets.write.
#
# Usage: langfuse.generate_secret <ENV_KEY> <SECRET_NAME>
langfuse.generate_secret() {
  local env_key="${1:?env_key is required}"
  local secret_name="${2:?secret_name is required}"

  # Check if already set (not a placeholder)
  local current_val
  current_val="$(grep -E "^[[:space:]]*${env_key}[[:space:]]*=" "${ENV_FILE}" 2>/dev/null \
    | head -1 | cut -d= -f2- | tr -d "\"' " || true)"

  if [[ -n "${current_val}" && "${current_val}" != "REPLACE_WITH"* ]]; then
    skip "${env_key} (already set in .env)"
    secrets.write "${secret_name}" "${current_val}"
    return 0
  fi

  step "Generating ${env_key}..."
  local new_val
  new_val="$(openssl rand -hex 32)"

  # Replace placeholder in .env
  if [[ -f "${ENV_FILE}" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      sed -i '' "s|^${env_key}=REPLACE_WITH.*|${env_key}=${new_val}|" "${ENV_FILE}"
    else
      sed -i "s|^${env_key}=REPLACE_WITH.*|${env_key}=${new_val}|" "${ENV_FILE}"
    fi
    log "${env_key} written to .env"
  else
    warn ".env not found — cannot write ${env_key}. Add manually: ${env_key}=${new_val}"
  fi

  secrets.write "${secret_name}" "${new_val}"
}

# ── Generate secrets ──────────────────────────────────────────────────────────
langfuse.generate_secret "LANGFUSE_SECRET" "langfuse-secret"
langfuse.generate_secret "LANGFUSE_SALT"   "langfuse-salt"

# ── Print connection instructions ─────────────────────────────────────────────
echo
echo -e "  ${TEXT_BOLD}Langfuse is enabled.${TEXT_CLEAR}"
echo
echo -e "  ${TEXT_BOLD}Web UI:${TEXT_CLEAR}  http://localhost:4000"
echo
echo -e "  ${TEXT_BOLD}First login:${TEXT_CLEAR}"
echo "    1. Open http://localhost:4000 in your browser."
echo "    2. Create an admin account."
echo "    3. Generate API keys in Settings → API Keys."
echo
echo -e "  ${TEXT_BOLD}Connect opencode to Langfuse:${TEXT_CLEAR}"
echo "    Export these env vars before starting opencode:"
echo "      export LANGFUSE_PUBLIC_KEY=<from Langfuse UI after first login>"
echo "      export LANGFUSE_SECRET_KEY=<from Langfuse UI after first login>"
echo "      export LANGFUSE_HOST=http://localhost:4000"
echo

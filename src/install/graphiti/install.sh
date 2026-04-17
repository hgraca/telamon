#!/usr/bin/env bash
# =============================================================================
# src/install/graphiti/install.sh
# Optional install module for Graphiti (temporal knowledge graph).
#
# Guarded by GRAPHITI_ENABLED=true in .env.
# Generates NEO4J_PASSWORD if not already set.
# Registers the Graphiti MCP server in opencode.jsonc.
#
# Note: The MCP command uses `npx -y graphiti-mcp`. Verify the npm package
# name is correct before enabling — see PLAN.md Escalation 1.
# =============================================================================

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SECRETS_DIR="${SECRETS_DIR:-$(cd "${INSTALL_PATH}/../.." && pwd)/storage/secrets}"
export INSTALL_PATH SECRETS_DIR

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Graphiti (temporal knowledge graph)"

# ── Guard: skip if not enabled ────────────────────────────────────────────────
env.is_enabled GRAPHITI_ENABLED || { skip "Graphiti (disabled)"; exit 0; }

ENV_FILE="${TELAMON_ROOT:?TELAMON_ROOT must be set}/.env"

# ── graphiti.generate_neo4j_password ─────────────────────────────────────────
# Generates a random Neo4j password and writes it into .env (replacing placeholder).
# Also writes to storage/secrets/neo4j-password via secrets.write.
graphiti.generate_neo4j_password() {
  local env_key="NEO4J_PASSWORD"
  local secret_name="neo4j-password"

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
  new_val="$(openssl rand -hex 16)"

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
graphiti.generate_neo4j_password

# ── Register Graphiti MCP server in opencode.jsonc ───────────────────────────
# Uses npx -y to auto-install the graphiti-mcp package on first run.
# Verify the npm package name before enabling: see PLAN.md Escalation 1.
step "Registering Graphiti MCP server in opencode.jsonc..."
opencode.upsert_mcp "graphiti" "$(cat <<JSON
{
  "type": "local",
  "command": ["npx", "-y", "graphiti-mcp", "--url", "http://localhost:8001"],
  "enabled": true
}
JSON
)"

# ── Print usage instructions ──────────────────────────────────────────────────
echo
echo -e "  ${TEXT_BOLD}Graphiti is enabled.${TEXT_CLEAR}"
echo
echo -e "  ${TEXT_BOLD}Services:${TEXT_CLEAR}"
echo "    Neo4j browser:  http://localhost:7474  (user: neo4j)"
echo "    Graphiti API:   http://localhost:8001"
echo
echo -e "  ${TEXT_BOLD}MCP server registered:${TEXT_CLEAR} graphiti"
echo "    Agents can now use Graphiti for temporal/relational queries:"
echo "      add_episode  — store a new episode (decision, event, relationship)"
echo "      search       — query the knowledge graph"
echo
echo -e "  ${TEXT_BOLD}Note:${TEXT_CLEAR} OPENAI_API_KEY is required by Graphiti for entity extraction."
echo "    If already set in your shell, it takes precedence over .env."
echo

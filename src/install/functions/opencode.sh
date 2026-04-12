#!/usr/bin/env bash
# Shared helpers for patching the ADK opencode config (storage/opencode.jsonc).

# Resolve the config file path: prefer an explicit override, then derive from
# INSTALL_PATH (always set by run.sh), then fall back to the global default.
if [[ -z "${OPENCODE_CONFIG_FILE:-}" ]]; then
  if [[ -n "${INSTALL_PATH:-}" ]]; then
    OPENCODE_CONFIG_FILE="$(cd "${INSTALL_PATH}/../.." && pwd)/storage/opencode.jsonc"
  else
    OPENCODE_CONFIG_FILE="$HOME/.config/opencode/opencode.json"
  fi
fi

# opencode.upsert_mcp <server-name> <json-block>
#
# Upserts a single MCP server block into opencode.json.
# If the server key already exists, its value is replaced.
# If opencode.json does not exist yet, the function is a no-op (base file
# must be created by opencode/install.sh first).
#
# Arguments:
#   $1 — MCP server name (key under .mcp)
#   $2 — JSON string for the server block (must be valid JSON)
#
# Example:
#   opencode.upsert_mcp "ogham" '{"type":"local","command":["uvx","ogham-mcp"],"enabled":true}'
opencode.upsert_mcp() {
  local server_name="$1"
  local server_json="$2"
  local config_file="${OPENCODE_CONFIG_FILE}"

  if [[ ! -f "${config_file}" ]]; then
    warn "opencode.json not found — skipping MCP registration for '${server_name}'"
    return 0
  fi

  python3 - "${config_file}" "${server_name}" "${server_json}" <<'PYEOF'
import json, sys

config_file, server_name, server_json = sys.argv[1], sys.argv[2], sys.argv[3]

with open(config_file) as f:
    config = json.load(f)

config.setdefault("mcp", {})[server_name] = json.loads(server_json)

with open(config_file, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print(f"  \033[32m✔\033[0m  MCP server '{server_name}' registered in opencode.json")
PYEOF
}

# opencode.set_mcp_env <server-name> <key> <value>
#
# Sets a single environment variable inside an existing MCP server block.
# No-op if the file or server block does not exist.
opencode.set_mcp_env() {
  local server_name="$1"
  local env_key="$2"
  local env_val="$3"
  local config_file="${OPENCODE_CONFIG_FILE}"

  if [[ ! -f "${config_file}" ]]; then
    warn "opencode.json not found — skipping env set for '${server_name}.${env_key}'"
    return 0
  fi

  python3 - "${config_file}" "${server_name}" "${env_key}" "${env_val}" <<'PYEOF'
import json, sys

config_file, server_name, env_key, env_val = sys.argv[1:]

with open(config_file) as f:
    config = json.load(f)

server = config.get("mcp", {}).get(server_name)
if server is None:
    print(f"  \033[33m⚠\033[0m  MCP server '{server_name}' not found — skipping env set")
    sys.exit(0)

server.setdefault("environment", {})[env_key] = env_val

with open(config_file, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print(f"  \033[32m✔\033[0m  {server_name}.environment.{env_key} set in opencode.json")
PYEOF
}

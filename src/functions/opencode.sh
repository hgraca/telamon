#!/usr/bin/env bash
# Shared helpers for patching Telamon opencode config (storage/opencode.jsonc).

# Resolve the config file path: prefer an explicit override, then derive from
# TOOLS_PATH (always set by run.sh), then fall back to the global default.
if [[ -z "${OPENCODE_CONFIG_FILE:-}" ]]; then
  if [[ -n "${TOOLS_PATH:-}" ]]; then
    OPENCODE_CONFIG_FILE="$(cd "${TOOLS_PATH}/../.." && pwd)/storage/opencode.jsonc"
  else
    OPENCODE_CONFIG_FILE="$HOME/.config/opencode/opencode.json"
  fi
fi

# opencode.upsert_mcp <server-name> <json-block>
#
# Upserts a single MCP server block into opencode.json/jsonc.
# If the server key already exists, its value is replaced.
# If the config file does not exist yet, the function is a no-op (base file
# must be created by opencode/install.sh first).
# JSONC comments (// and /* */) are stripped before parsing so the file may
# contain human-readable comments and they are preserved on write via
# round-tripping through the tokenizer — note: comments are NOT preserved
# after the first upsert (json.dump writes clean JSON). This is intentional:
# the file starts as JSONC for readability but becomes plain JSON after tools
# patch it.
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
    warn "opencode config not found — skipping MCP registration for '${server_name}'"
    return 0
  fi

  python3 - "${FUNCTIONS_PATH}/strip_jsonc.py" "${config_file}" "${server_name}" "${server_json}" <<'PYEOF'
import json, sys

exec(open(sys.argv[1]).read())

config_file, server_name, server_json = sys.argv[2], sys.argv[3], sys.argv[4]

with open(config_file) as f:
    config = json.loads(strip_jsonc_comments(f.read()))

config.setdefault("mcp", {})[server_name] = json.loads(server_json)

with open(config_file, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print(f"  \033[32m✔\033[0m  MCP server '{server_name}' registered in opencode config")
PYEOF
}

# opencode.upsert_plugin <plugin-path>
#
# Adds a plugin path to the "plugin" list in opencode.jsonc if not already present.
#
# Arguments:
#   $1 — plugin path string (e.g. ".opencode/plugins/graphify.js")
#
# Example:
#   opencode.upsert_plugin ".opencode/plugins/graphify.js"
opencode.upsert_plugin() {
  local plugin_path="$1"
  local config_file="${OPENCODE_CONFIG_FILE}"

  if [[ ! -f "${config_file}" ]]; then
    warn "opencode config not found — skipping plugin registration for '${plugin_path}'"
    return 0
  fi

  python3 - "${FUNCTIONS_PATH}/strip_jsonc.py" "${config_file}" "${plugin_path}" <<'PYEOF'
import json, sys

exec(open(sys.argv[1]).read())

config_file, plugin_path = sys.argv[2], sys.argv[3]

with open(config_file) as f:
    config = json.loads(strip_jsonc_comments(f.read()))

plugins = config.setdefault("plugin", [])
if plugin_path not in plugins:
    plugins.append(plugin_path)
    with open(config_file, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
    print(f"  \033[32m✔\033[0m  Plugin '{plugin_path}' registered in opencode config")
else:
    print(f"  \033[2m–  {plugin_path} already in plugin list (skipped)\033[0m")
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
    warn "opencode config not found — skipping env set for '${server_name}.${env_key}'"
    return 0
  fi

  python3 - "${FUNCTIONS_PATH}/strip_jsonc.py" "${config_file}" "${server_name}" "${env_key}" "${env_val}" <<'PYEOF'
import json, sys

exec(open(sys.argv[1]).read())

config_file, server_name, env_key, env_val = sys.argv[2:]

with open(config_file) as f:
    config = json.loads(strip_jsonc_comments(f.read()))

server = config.get("mcp", {}).get(server_name)
if server is None:
    print(f"  \033[33m⚠\033[0m  MCP server '{server_name}' not found — skipping env set")
    sys.exit(0)

server.setdefault("environment", {})[env_key] = env_val

with open(config_file, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print(f"  \033[32m✔\033[0m  {server_name}.environment.{env_key} set in opencode config")
PYEOF
}

# opencode.set_permission <key> <json-value>
#
# Sets a single key inside the "permission" block of opencode.jsonc.
# The value may be a plain JSON string (e.g. '"deny"') or a JSON object.
# If the "permission" key does not exist it is created.
# No-op if the config file does not exist.
#
# Arguments:
#   $1 — permission key (e.g. "external_directory")
#   $2 — JSON value string (must be valid JSON, e.g. '"deny"' or '{"*":"deny"}')
#
# Example:
#   opencode.set_permission "external_directory" '{"*": "deny", "/path/to/storage/obsidian/*": "allow"}'
opencode.set_permission() {
  local perm_key="$1"
  local perm_json="$2"
  local config_file="${OPENCODE_CONFIG_FILE}"

  if [[ ! -f "${config_file}" ]]; then
    warn "opencode config not found — skipping permission set for '${perm_key}'"
    return 0
  fi

  python3 - "${FUNCTIONS_PATH}/strip_jsonc.py" "${config_file}" "${perm_key}" "${perm_json}" <<'PYEOF'
import json, sys

exec(open(sys.argv[1]).read())

config_file, perm_key, perm_json = sys.argv[2], sys.argv[3], sys.argv[4]

with open(config_file) as f:
    config = json.loads(strip_jsonc_comments(f.read()))

config.setdefault("permission", {})[perm_key] = json.loads(perm_json)

with open(config_file, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print(f"  \033[32m✔\033[0m  permission.{perm_key} set in opencode config")
PYEOF
}

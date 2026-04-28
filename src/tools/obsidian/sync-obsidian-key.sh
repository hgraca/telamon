#!/usr/bin/env bash
# Sync the Obsidian Local REST API key from the plugin's data.json into
# Telamon's secrets file so the MCP server can authenticate.
# Safe to run on every `make up` — no-op if key is unchanged or plugin is absent.

set -euo pipefail

TELAMON_ROOT="${TELAMON_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

PLUGIN_DATA="${TELAMON_ROOT}/storage/obsidian/.obsidian/plugins/obsidian-local-rest-api/data.json"
SECRETS_FILE="${TELAMON_ROOT}/storage/secrets/obsidian-api-key"

# ── Guards ─────────────────────────────────────────────────────────────────────
if [[ ! -f "${PLUGIN_DATA}" ]]; then
  echo "  – Obsidian API key sync skipped (plugin data.json not found)"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "  ⚠ Obsidian API key sync skipped (jq not installed)"
  exit 0
fi

# ── Extract and sync ──────────────────────────────────────────────────────────
API_KEY="$(jq -r '.apiKey // empty' "${PLUGIN_DATA}")"

if [[ -z "${API_KEY}" ]]; then
  echo "  ⚠ Obsidian API key sync skipped (apiKey not set in plugin data)"
  exit 0
fi

# Skip write if key is unchanged
if [[ -f "${SECRETS_FILE}" ]] && [[ "$(cat "${SECRETS_FILE}")" == "${API_KEY}" ]]; then
  echo "  ✓ Obsidian API key (unchanged)"
  exit 0
fi

mkdir -p "$(dirname "${SECRETS_FILE}")"
printf '%s' "${API_KEY}" > "${SECRETS_FILE}"
echo "  ✓ Obsidian API key synced"

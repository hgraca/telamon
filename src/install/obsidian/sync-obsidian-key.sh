#!/usr/bin/env bash
set -euo pipefail

OBSIDIAN_PLUGIN_DATA="/home/herberto/Documents/obsidian-vault/.obsidian/plugins/obsidian-local-rest-api/data.json"
SECRETS_FILE="/home/herberto/Development/Get-e/k8s-gete/.ai/telamon/secrets/obsidian-api-key"

API_KEY=$(jq -r '.apiKey' "$OBSIDIAN_PLUGIN_DATA")

if [[ -z "$API_KEY" || "$API_KEY" == "null" ]]; then
  echo "ERROR: Could not extract apiKey from $OBSIDIAN_PLUGIN_DATA" >&2
  exit 1
fi

printf '%s' "$API_KEY" > "$SECRETS_FILE"
echo "Obsidian API key synced to $SECRETS_FILE"

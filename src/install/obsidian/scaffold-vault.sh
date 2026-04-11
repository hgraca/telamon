#!/usr/bin/env bash
# Create the Obsidian vault brain/ folder structure for the current project.
# Idempotent: skipped if brain/NorthStar.md already exists.
#
# Required env vars:
#   PROJECT_NAME       — display name for the project (used as vault subfolder)
#   STATE_DIR          — state directory (default: ~/.config/ogham)
#
# Templates used (co-located in src/install/obsidian/ — placeholders PROJECT_NAME /
# DATE_PLACEHOLDER are substituted via sed):
#   NorthStar.md
#   KeyDecisions.md
#   Patterns.md
#   Gotchas.md

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

: "${PROJECT_NAME:?PROJECT_NAME is required}"
STATE_DIR="${STATE_DIR:-$HOME/.config/ogham}"

header "Obsidian Vault — brain/ scaffold"

# Load saved vault path
saved_vault=""
[[ -f "${STATE_DIR}/setup-inputs" ]] && source "${STATE_DIR}/setup-inputs" 2>/dev/null || true
saved_vault="${SAVED_VAULT_PATH:-}"

if [[ -z "${saved_vault}" ]]; then
  skip "Vault brain/ scaffold (no vault path saved — set Obsidian API key first)"
  exit 0
fi

BRAIN_DIR="${saved_vault}/${PROJECT_NAME}/brain"

if [[ -f "${BRAIN_DIR}/NorthStar.md" ]]; then
  skip "Vault brain/ structure (already exists for ${PROJECT_NAME})"
  exit 0
fi

TODAY=""
TODAY="$(date +%Y-%m-%d)"

step "Creating vault structure for ${PROJECT_NAME}..."
mkdir -p \
  "${BRAIN_DIR}" \
  "${saved_vault}/${PROJECT_NAME}/work/active" \
  "${saved_vault}/${PROJECT_NAME}/work/archive" \
  "${saved_vault}/${PROJECT_NAME}/work/incidents" \
  "${saved_vault}/${PROJECT_NAME}/reference" \
  "${saved_vault}/${PROJECT_NAME}/thinking"

# Helper: substitute placeholders and write a vault note
_write_vault_note() {
  local template="$1"
  local dest="$2"
  sed \
    -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
    -e "s/DATE_PLACEHOLDER/${TODAY}/g" \
    "${SCRIPT_DIR}/${template}" > "${dest}"
}

_write_vault_note "NorthStar.md"       "${BRAIN_DIR}/NorthStar.md"
_write_vault_note "KeyDecisions.md"    "${BRAIN_DIR}/KeyDecisions.md"
_write_vault_note "Patterns.md"        "${BRAIN_DIR}/Patterns.md"
_write_vault_note "Gotchas.md"         "${BRAIN_DIR}/Gotchas.md"

log "Vault brain/ structure created at ${saved_vault}/${PROJECT_NAME}/"
info "Edit ${BRAIN_DIR}/NorthStar.md to set project goals — the agent reads this every session."

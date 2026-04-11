#!/usr/bin/env bash
# Write or update the AGENTS.md file in the current project directory.
#
# Behaviour:
#   - If AGENTS.md exists and has the ogham-managed marker → refresh the ogham profile
#   - If AGENTS.md exists but has NO marker → ask to append the memory block
#   - If AGENTS.md does not exist → create it from template
#
# Required env vars:
#   OGHAM_PROFILE  — active Ogham profile name
#   PROJECT_NAME   — display name for the project
#
# Template files used (co-located in src/install/opencode/):
#   project-AGENTS.md         — full new file template
#   project-AGENTS-append.md  — append block for existing files

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

: "${OGHAM_PROFILE:?OGHAM_PROFILE is required}"
: "${PROJECT_NAME:?PROJECT_NAME is required}"

header "Project AGENTS.md  →  $(pwd)"

PROJECT_AGENTS="$(pwd)/AGENTS.md"
MARKER="<!-- ogham-managed -->"

if [[ -f "${PROJECT_AGENTS}" ]] && grep -q "${MARKER}" "${PROJECT_AGENTS}"; then
  # Refresh the ogham profile reference in the existing managed file
  step "Refreshing profile in existing AGENTS.md..."
  python3 - "${PROJECT_AGENTS}" "${OGHAM_PROFILE}" <<'PYEOF'
import re, sys
path, profile = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
content = re.sub(r'(ogham use )\S+', f'\\g<1>{profile}', content)
with open(path, 'w') as f:
    f.write(content)
PYEOF
  log "AGENTS.md updated (profile: ${OGHAM_PROFILE})"

elif [[ -f "${PROJECT_AGENTS}" ]] && ! grep -q "${MARKER}" "${PROJECT_AGENTS}"; then
  warn "AGENTS.md exists (not managed by this script)."
  ask "Append memory setup block? (Y/n):"
  read -r APPEND_CONFIRM
  if [[ "${APPEND_CONFIRM}" =~ ^[Nn] ]]; then
    info "Skipped — AGENTS.md unchanged"
  else
    # Substitute placeholders in append template and append to file
    sed \
      -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
      -e "s/OGHAM_PROFILE/${OGHAM_PROFILE}/g" \
      "${SCRIPT_DIR}/project-AGENTS-append.md" >> "${PROJECT_AGENTS}"
    log "Memory block appended"
  fi

else
  # Create new AGENTS.md from template, substituting placeholders
  sed \
    -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
    -e "s/OGHAM_PROFILE/${OGHAM_PROFILE}/g" \
    "${SCRIPT_DIR}/project-AGENTS.md" > "${PROJECT_AGENTS}"
  log "Project AGENTS.md created → ${PROJECT_AGENTS}"
  info "Edit $(pwd)/AGENTS.md — add stack, conventions, build commands above the Memory section."
  info "Create ${PROJECT_NAME}/brain/NorthStar.md in your Obsidian vault with project goals."
fi

step "Activating Ogham profile: ${OGHAM_PROFILE}"
ogham use "${OGHAM_PROFILE}" 2>/dev/null \
  && log "Profile active" \
  || warn "Could not switch profile — run 'ogham health' to check"

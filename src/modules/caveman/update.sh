#!/usr/bin/env bash
# Refresh the caveman skill file from the upstream repository.
# caveman has no binary — it is a skill-only tool, so there is nothing
# to skip when not installed: the skill download always runs.
# Exit codes: 0=success  1=failed

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "caveman"

SKILL_URL="https://raw.githubusercontent.com/JuliusBrussee/caveman/main/skills/caveman/SKILL.md"
SKILL_FILE="${TELAMON_ROOT}/src/instructions/skills/workflow/caveman/SKILL.md"

step "Updating caveman skill → src/instructions/skills/workflow/caveman/SKILL.md ..."
mkdir -p "$(dirname "${SKILL_FILE}")"
if ! curl -fsSL "${SKILL_URL}" -o "${SKILL_FILE}" 2>/dev/null; then
  warn "caveman skill update failed — run manually: curl -fsSL ${SKILL_URL} -o ${SKILL_FILE}"
  exit 1
fi

# Ensure opencode-compatible frontmatter is present so the skill is registered.
# Upstream may ship the file without frontmatter; if missing, prepend it.
if ! head -n 1 "${SKILL_FILE}" | grep -qx -- '---'; then
  step "Prepending frontmatter to caveman SKILL.md ..."
  TMP_FILE="$(mktemp)"
  cat > "${TMP_FILE}" <<'EOF'
---
name: caveman
description: >
  Ultra-compressed communication mode. Cuts token usage ~75% by speaking like caveman
  while keeping full technical accuracy. Supports intensity levels: lite, full (default), ultra,
  wenyan-lite, wenyan-full, wenyan-ultra.
  Use when user says "caveman mode", "talk like caveman", "use caveman", "less tokens",
  "be brief", or invokes /caveman. Also auto-triggers when token efficiency is requested.
---

EOF
  cat "${SKILL_FILE}" >> "${TMP_FILE}"
  mv "${TMP_FILE}" "${SKILL_FILE}"
fi

log "caveman skill updated"

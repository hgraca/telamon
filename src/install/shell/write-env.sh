#!/usr/bin/env bash
# Add the AI memory stack entries to the user's shell RC file.
# Idempotent: refreshes values in place if the block already exists.
#
# Reads OBSIDIAN_API_KEY from .env if not already set in the environment.
# Writes shell exports for OBSIDIAN_API_KEY and OGHAM_PROFILE; skips
# OBSIDIAN_API_KEY silently if it is still unset or a placeholder.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# ── Resolve OBSIDIAN_API_KEY from .env if not injected by caller ──────────────
ADK_ROOT="$(cd "${INSTALL_PATH}/../.." && pwd)"
ENV_FILE="${ADK_ROOT}/.env"
if [[ -z "${OBSIDIAN_API_KEY:-}" && -f "${ENV_FILE}" ]]; then
  _key="$(grep -E "^[[:space:]]*OBSIDIAN_API_KEY[[:space:]]*=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d "\"' ")"
  [[ -n "${_key}" && "${_key}" != "REPLACE_WITH"* ]] && OBSIDIAN_API_KEY="${_key}" || OBSIDIAN_API_KEY=""
fi
OBSIDIAN_API_KEY="${OBSIDIAN_API_KEY:-}"

: "${OGHAM_PROFILE:?OGHAM_PROFILE is required}"

header "Shell Environment"

OS=$(os.get_os)

SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == *"bash"* ]]; then
  SHELL_RC="$HOME/.bashrc"
  [[ "${OS}" == "macos" ]] && SHELL_RC="$HOME/.bash_profile"
fi

MARKER="# ai-memory-stack"

if grep -q "${MARKER}" "${SHELL_RC}" 2>/dev/null; then
  # Refresh values in place
  python3 - "${SHELL_RC}" "${OBSIDIAN_API_KEY}" "${OGHAM_PROFILE}" <<'PYEOF'
import re, sys
path, key, profile = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    content = f.read()
content = re.sub(r'export OBSIDIAN_API_KEY=.*', f'export OBSIDIAN_API_KEY="{key}"', content)
content = re.sub(r'export OGHAM_PROFILE=.*',    f'export OGHAM_PROFILE="{profile}"', content)
with open(path, 'w') as f:
    f.write(content)
PYEOF
  skip "Shell env (refreshed values in ${SHELL_RC})"
else
  # Determine the Homebrew path init line
  BREW_PATH_LINE=""
  if [[ "${OS}" == "macos" ]]; then
    BREW_PATH_LINE='eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true'
  else
    BREW_PATH_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true'
  fi

  cat >> "${SHELL_RC}" <<SH

${MARKER}
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"
${BREW_PATH_LINE}
export OBSIDIAN_API_KEY="${OBSIDIAN_API_KEY}"
export OGHAM_PROFILE="${OGHAM_PROFILE}"
SH
  log "Shell env added to ${SHELL_RC}"
fi

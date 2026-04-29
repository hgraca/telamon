#!/usr/bin/env bash
# Add the AI memory stack entries to the user's shell RC file.
# Idempotent: refreshes values in place if the block already exists.
#
# Reads OBSIDIAN_API_KEY from .env if not already set in the environment.
# Writes shell export for OBSIDIAN_API_KEY; skips silently if it is still
# unset or a placeholder.
#
# Also writes a qmd() wrapper function that sets XDG_CACHE_HOME so that
# interactive `qmd` commands use Telamon's centralised storage/qmd/ directory
# instead of the system-wide ~/.cache/qmd/.  The path is hardcoded at install
# time because XDG_CACHE_HOME must be absolute.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# ── Resolve OBSIDIAN_API_KEY from .env if not injected by caller ──────────────
TELAMON_ROOT="$(cd "${TOOLS_PATH}/../.." && pwd)"
ENV_FILE="${TELAMON_ROOT}/.env"
if [[ -z "${OBSIDIAN_API_KEY:-}" && -f "${ENV_FILE}" ]]; then
  _key="$(grep -E "^[[:space:]]*OBSIDIAN_API_KEY[[:space:]]*=" "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d "\"' ")"
  [[ -n "${_key}" && "${_key}" != "REPLACE_WITH"* ]] && OBSIDIAN_API_KEY="${_key}" || OBSIDIAN_API_KEY=""
fi
OBSIDIAN_API_KEY="${OBSIDIAN_API_KEY:-}"

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
  python3 - "${SHELL_RC}" "${OBSIDIAN_API_KEY}" <<'PYEOF'
import re, sys
path, key = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
content = re.sub(r'export OBSIDIAN_API_KEY=.*', f'export OBSIDIAN_API_KEY="{key}"', content)
# Remove legacy OGHAM_PROFILE export if present
content = re.sub(r'\nexport OGHAM_PROFILE=.*', '', content)
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
SH
  log "Shell env added to ${SHELL_RC}"
fi

# ── QMD wrapper function ───────────────────────────────────────────────────────
# Writes (or refreshes) a qmd() shell function that sets XDG_CACHE_HOME to the
# Telamon's storage directory.  This ensures every interactive `qmd` invocation uses
# storage/qmd/index.sqlite rather than the default ~/.cache/qmd/index.sqlite.
#
# Telamon scripts and the opencode MCP server set XDG_CACHE_HOME themselves;
# this wrapper covers interactive terminal use.

QMD_MARKER="# ai-qmd-wrapper"
QMD_STORAGE="${TELAMON_ROOT}/storage"

if grep -q "${QMD_MARKER}" "${SHELL_RC}" 2>/dev/null; then
  # Refresh the hardcoded path in-place (handles Telamon directory moves/renames)
  python3 - "${SHELL_RC}" "${QMD_STORAGE}" <<'PYEOF'
import re, sys
path, storage = sys.argv[1], sys.argv[2]
with open(path) as f:
    content = f.read()
# Replace the XDG_CACHE_HOME value inside the qmd wrapper function
content = re.sub(
    r'(XDG_CACHE_HOME=")[^"]*(" command qmd)',
    rf'\g<1>{storage}\g<2>',
    content,
)
with open(path, 'w') as f:
    f.write(content)
PYEOF
  skip "QMD shell wrapper (refreshed path in ${SHELL_RC})"
else
  cat >> "${SHELL_RC}" <<SH

${QMD_MARKER}
# Redirect QMD cache to Telamon's centralised storage directory.
# XDG_CACHE_HOME must be absolute; path is refreshed by 'make up'.
qmd() { XDG_CACHE_HOME="${QMD_STORAGE}" command qmd "\$@"; }
SH
  log "QMD shell wrapper added to ${SHELL_RC}"
fi

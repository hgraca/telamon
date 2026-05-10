#!/usr/bin/env bash
# Install the remember-session post-commit hook into the current project.
#
# Adds a line to .git/hooks/post-commit that invokes the module's runner in
# the background. The runner itself decides whether to fire (it short-circuits
# when OPENCODE_SESSION_ID is unset, so human commits are unaffected).
#
# Re-running this script replaces only this module's hook section — other
# modules' contributions to post-commit are preserved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

PROJ="${PROJ:?PROJ env var is required}"
PROJ="$(cd "${PROJ}" && pwd)"
export PROJ

header "git-hook-remember-session"

RUNNER="${SCRIPT_DIR}/remember-session-hook-runner.sh"

if [[ ! -f "${RUNNER}" ]]; then
  warn "remember-session-hook-runner.sh missing — skipping hook install"
  exit 0
fi

# Background + disown — prevents MCP git server from waiting on child
# processes (Python subprocess waits until inherited FDs close).
BODY="bash \"${RUNNER}\" \"${PROJ}\" >/dev/null 2>&1 & disown"
install_telamon_hook "post-commit" "${BODY}"

log "remember-session post-commit hook installed in ${PROJ}"

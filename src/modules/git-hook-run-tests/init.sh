#!/usr/bin/env bash
# Install the run-tests pre-commit hook into the current project.
#
# Adds a blocking call to .git/hooks/pre-commit that runs
# `make test DRY_RUN=--dry-run` before allowing the commit to proceed. The
# runner short-circuits to exit 0 when OPENCODE_SESSION_ID is unset, so human
# commits are never gated by this hook.
#
# Re-running this script replaces only this module's hook section — other
# modules' contributions to pre-commit are preserved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

PROJ="${PROJ:?PROJ env var is required}"
PROJ="$(cd "${PROJ}" && pwd)"
export PROJ

header "git-hook-run-tests"

RUNNER="${SCRIPT_DIR}/run-tests-hook-runner.sh"

if [[ ! -f "${RUNNER}" ]]; then
  warn "run-tests-hook-runner.sh missing — skipping hook install"
  exit 0
fi

# Foreground — a non-zero exit aborts the commit so the LLM sees the failure.
BODY="bash \"${RUNNER}\" \"${PROJ}\" || exit 1"
install_telamon_hook "pre-commit" "${BODY}" "RUN-TESTS"

log "run-tests pre-commit hook installed in ${PROJ}"

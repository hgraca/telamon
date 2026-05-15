#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/git-report/git-report.sh
# CLI wrapper for the git-report tool — snapshots current git state and
# outputs markdown or JSON to stdout.
#
# Usage:
#   telamon tool git-report                    # markdown output (default)
#   telamon tool git-report --json             # JSON output
#   telamon tool git-report --markdown         # explicit markdown
#   telamon tool git-report --log-count 20     # show 20 recent commits
#
# Defaults:
#   --format: markdown (shell default; JS tool defaults to json)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"

TOOL_SCRIPT="${TELAMON_ROOT}/src/instructions/tools/git-report/git-report.py"

if [[ ! -f "${TOOL_SCRIPT}" ]]; then
  echo "Error: git-report.py not found at ${TOOL_SCRIPT}" >&2
  exit 1
fi

# Parse args: --markdown and --json are convenience aliases for --format
HAS_FORMAT=false
ARGS=()
NEXT_IS_VALUE=false
NEXT_IS_FLAG=""
for arg in "$@"; do
  if $NEXT_IS_VALUE; then
    ARGS+=("${arg}")
    if [[ "${NEXT_IS_FLAG}" == "--format" ]]; then HAS_FORMAT=true; fi
    NEXT_IS_VALUE=false
    NEXT_IS_FLAG=""
  elif [[ "${arg}" == "--markdown" ]]; then
    ARGS+=("--format" "markdown")
    HAS_FORMAT=true
  elif [[ "${arg}" == "--json" ]]; then
    ARGS+=("--format" "json")
    HAS_FORMAT=true
  elif [[ "${arg}" == --* ]]; then
    ARGS+=("${arg}")
    NEXT_IS_VALUE=true
    NEXT_IS_FLAG="${arg}"
  else
    # Positional args not meaningful for git-report; pass through as-is
    ARGS+=("${arg}")
  fi
done

# Inject default format
if ! $HAS_FORMAT; then
  ARGS+=("--format" "markdown")
fi

exec python3 "${TOOL_SCRIPT}" "${ARGS[@]}"

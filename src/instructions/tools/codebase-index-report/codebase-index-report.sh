#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/codebase-index-report/codebase-index-report.sh
# CLI wrapper for the codebase-index-report tool — searches the codebase by
# meaning using the codebase-index MCP and returns full code contents.
#
# Usage:
#   telamon tool codebase-index-report "rate limiter"          # positional → --query
#   telamon tool codebase-index-report "payment handler" "auth" # multiple queries
#   telamon tool codebase-index-report --query "rate limiter"   # explicit flag
#   telamon tool codebase-index-report "rate limiter" --file-type ts
#   telamon tool codebase-index-report "rate limiter" --directory src/utils
#
# Positional args are converted to --query flags. Explicit --flags pass through
# with their values.
#
# Defaults:
#   --format: markdown
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"

TOOL_SCRIPT="${TELAMON_ROOT}/src/instructions/tools/codebase-index-report/codebase-index-report.py"

if [[ ! -f "${TOOL_SCRIPT}" ]]; then
  echo "Error: codebase-index-report.py not found at ${TOOL_SCRIPT}" >&2
  exit 1
fi

# Parse args: positional → --query, explicit --flags pass through with values
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
  elif [[ "${arg}" == --* ]]; then
    ARGS+=("${arg}")
    NEXT_IS_VALUE=true
    NEXT_IS_FLAG="${arg}"
  else
    ARGS+=("--query" "${arg}")
  fi
done

# Inject defaults for missing flags
if ! $HAS_FORMAT; then
  ARGS+=("--format" "markdown")
fi

exec python3 "${TOOL_SCRIPT}" "${ARGS[@]}"
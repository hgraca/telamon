#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/repomix-report/repomix-report.sh
# CLI wrapper for the repomix-report tool — packages folders with --compress
# and outputs markdown to stdout.
#
# Usage:
#   telamon tool repomix-report src/components                    # positional → --dir
#   telamon tool repomix-report src/components src/utils          # multiple dirs
#   telamon tool repomix-report --dir src/components              # explicit flag
#   telamon tool repomix-report src --no-compress                 # disable compression
#   telamon tool repomix-report src --markdown                    # force markdown output
#   telamon tool repomix-report src --json                        # force JSON output
#
# Positional args are converted to --dir flags. Explicit --flags pass through
# with their values.
#
# Defaults:
#   --format: markdown (shell default; JS tool defaults to json)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"

TOOL_SCRIPT="${TELAMON_ROOT}/src/instructions/tools/repomix-report/repomix-report.py"

if [[ ! -f "${TOOL_SCRIPT}" ]]; then
  echo "Error: repomix-report.py not found at ${TOOL_SCRIPT}" >&2
  exit 1
fi

# Parse args: positional → --dir, explicit --flags pass through with values
# --markdown and --json are convenience aliases for --format markdown|json
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
    ARGS+=("--dir" "${arg}")
  fi
done

# Inject default format
if ! $HAS_FORMAT; then
  ARGS+=("--format" "markdown")
fi

exec python3 "${TOOL_SCRIPT}" "${ARGS[@]}"
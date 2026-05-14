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
#
# Positional args are converted to --dir flags. Explicit --flags pass through
# with their values.
#
# Always outputs markdown to stdout (no file written).
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
ARGS=()
NEXT_IS_VALUE=false
for arg in "$@"; do
  if $NEXT_IS_VALUE; then
    ARGS+=("${arg}")
    NEXT_IS_VALUE=false
  elif [[ "${arg}" == --* ]]; then
    ARGS+=("${arg}")
    NEXT_IS_VALUE=true
  else
    ARGS+=("--dir" "${arg}")
  fi
done

exec python3 "${TOOL_SCRIPT}" "${ARGS[@]}"
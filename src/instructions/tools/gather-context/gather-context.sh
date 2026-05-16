#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/gather-context/gather-context.sh
# CLI wrapper for the gather-context tool — orchestrates context-gathering
# tools for a set of keywords.
#
# Usage:
#   gather-context.sh planning workflow          # positional keywords, markdown
#   gather-context.sh "planning" "workflow"      # quoted keywords
#   gather-context.sh planning --json            # force JSON output
#   gather-context.sh planning --markdown        # explicit markdown
#   gather-context.sh planning --format json     # explicit --format flag
#   gather-context.sh planning --max-results 3   # fewer results
#
# Positional args are treated as individual keywords.
# Defaults:
#   --format: markdown (shell default; JS tool defaults to json)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"

TOOL_SCRIPT="${TELAMON_ROOT}/src/instructions/tools/gather-context/gather-context.py"

if [[ ! -f "${TOOL_SCRIPT}" ]]; then
  echo "Error: gather-context.py not found at ${TOOL_SCRIPT}" >&2
  exit 1
fi

# Parse args: positional → keywords, explicit --flags pass through with values
HAS_FORMAT=false
POSITIONAL=()
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
    POSITIONAL+=("${arg}")
  fi
done

for kw in "${POSITIONAL[@]}"; do
  ARGS+=("${kw}")
done

if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
  echo "Usage: gather-context.sh [--markdown|--json|--format markdown|json] <keyword> [<keyword> ...]" >&2
  exit 1
fi

if ! $HAS_FORMAT; then
  ARGS+=("--format" "markdown")
fi

export XDG_CACHE_HOME="${TELAMON_ROOT}/storage"
export QMD_LLAMA_GPU=true

exec python3 "${TOOL_SCRIPT}" "${ARGS[@]}"

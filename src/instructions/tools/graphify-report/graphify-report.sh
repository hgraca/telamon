#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/graphify-report/graphify-report.sh
# CLI wrapper for the graphify-report tool — reads graph.json and produces
# a Markdown report (stats, god nodes, communities, word deep-dive).
#
# Usage:
#   telamon tool graphify-report                        # summary mode
#   telamon tool graphify-report planning workflow       # positional → --words
#   telamon tool graphify-report --words planning,workflow  # explicit flag
#   telamon tool graphify-report --graph-path path/to/graph.json
#
# Positional args are joined with commas as --words. Explicit --flags pass
# through with their values.
#
# Defaults:
#   --format: markdown
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"

TOOL_SCRIPT="${TELAMON_ROOT}/src/instructions/tools/graphify-report/graphify-report.py"

if [[ ! -f "${TOOL_SCRIPT}" ]]; then
  echo "Error: graphify-report.py not found at ${TOOL_SCRIPT}" >&2
  exit 1
fi

# Parse args: positional → --words, explicit --flags pass through with values
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
  elif [[ "${arg}" == --* ]]; then
    ARGS+=("${arg}")
    NEXT_IS_VALUE=true
    NEXT_IS_FLAG="${arg}"
  else
    POSITIONAL+=("${arg}")
  fi
done

if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  IFS=,; WORDS="${POSITIONAL[*]}"; unset IFS
  ARGS+=("--words" "${WORDS}")
fi

# Inject defaults for missing flags
if ! $HAS_FORMAT; then
  ARGS+=("--format" "markdown")
fi

exec python3 "${TOOL_SCRIPT}" "${ARGS[@]}"
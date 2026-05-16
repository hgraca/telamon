#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/gather-context-from-code/gather-context-from-code.sh
# CLI wrapper for the gather-context-from-code tool.
#
# Orchestrates graphify-report to find the most relevant file and folder nodes
# for a set of words/sentences, deduplicates overlapping folders (keeping the
# coarsest paths), and runs tree on each folder.
#
# Usage:
#   gather-context-from-code.sh planning workflow          # positional → words
#   gather-context-from-code.sh "memory management"        # quoted phrase
#   gather-context-from-code.sh planning --json            # force JSON output
#   gather-context-from-code.sh planning --markdown        # explicit markdown
#   gather-context-from-code.sh planning --format json     # explicit --format
#   gather-context-from-code.sh planning --top-n 5         # fewer results
#   gather-context-from-code.sh planning --graph-path path/to/graph.json
#
# Positional args are treated as individual words/sentences.
# Defaults:
#   --format: markdown (shell default; JS tool defaults to json)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"

TOOL_SCRIPT="${TELAMON_ROOT}/src/instructions/tools/gather-context-from-code/gather-context-from-code.py"

if [[ ! -f "${TOOL_SCRIPT}" ]]; then
  echo "Error: gather-context-from-code.py not found at ${TOOL_SCRIPT}" >&2
  exit 1
fi

# Parse args: positional → words, explicit --flags pass through with values
# --markdown and --json are convenience aliases for --format markdown|json
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

if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
  echo "Usage: gather-context-from-code.sh [--markdown|--json|--format markdown|json] [--top-n N] [--graph-path PATH] <word> [<word> ...]" >&2
  exit 1
fi

# Positional args are passed directly as individual words
for word in "${POSITIONAL[@]}"; do
  ARGS+=("${word}")
done

# Inject default format
if ! $HAS_FORMAT; then
  ARGS+=("--format" "markdown")
fi

exec python3 "${TOOL_SCRIPT}" "${ARGS[@]}"

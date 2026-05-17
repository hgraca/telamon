#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/search-memories/search-memories.sh
# CLI wrapper for the search-memories tool — searches the memory vault and
# returns full file bodies to stdout.
#
# Usage:
#   telamon tool search-memories billing erp
#   telamon tool search-memories "planning workflow"
#   telamon tool search-memories billing erp --json
#   telamon tool search-memories billing --collection myproject --max-results 10
#
# Positional arguments are treated as search queries (one per word/phrase).
# Defaults:
#   --format: markdown (shell default; JS tool defaults to json)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOOL_SCRIPT="${SCRIPT_DIR}/search-memories.py"

if [[ ! -f "${TOOL_SCRIPT}" ]]; then
  echo "Error: search-memories.py not found at ${TOOL_SCRIPT}" >&2
  exit 1
fi

# Parse args: positional args become --query values; flags pass through.
FORMAT="markdown"
HAS_FORMAT=false
QUERIES=()
EXTRA_ARGS=()
SKIP_NEXT=false

for i in "$@"; do
  if $SKIP_NEXT; then
    SKIP_NEXT=false
    continue
  fi
  case "${i}" in
    --markdown)
      FORMAT="markdown"; HAS_FORMAT=true ;;
    --json)
      FORMAT="json"; HAS_FORMAT=true ;;
    --format)
      HAS_FORMAT=true
      SKIP_NEXT=false  # handled below via index
      ;;
    --format=*)
      FORMAT="${i#--format=}"; HAS_FORMAT=true ;;
    --collection|--max-results)
      EXTRA_ARGS+=("${i}") ;;
    --*)
      EXTRA_ARGS+=("${i}") ;;
    *)
      QUERIES+=("${i}") ;;
  esac
done

# Handle --format <value> (two-token form) by re-parsing with index
ARGS=()
i=0
ARGV=("$@")
while [[ $i -lt ${#ARGV[@]} ]]; do
  arg="${ARGV[$i]}"
  if [[ "${arg}" == "--format" && $((i+1)) -lt ${#ARGV[@]} ]]; then
    FORMAT="${ARGV[$((i+1))]}"
    HAS_FORMAT=true
    i=$((i+2))
    continue
  fi
  i=$((i+1))
done

CMD=("python3" "${TOOL_SCRIPT}" "--format" "${FORMAT}")

for q in "${QUERIES[@]}"; do
  CMD+=("--query" "${q}")
done

CMD+=("${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}")

exec "${CMD[@]}"

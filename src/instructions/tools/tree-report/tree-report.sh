#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/tree-report/tree-report.sh
# CLI wrapper for the tree-report tool — runs `tree` on one or more directories
# and outputs markdown to stdout.
#
# Usage:
#   tree-report.sh src/components                    # single dir
#   tree-report.sh src/components src/utils          # multiple dirs
#
# Each directory gets its own fenced code block in the output.
# Always outputs markdown to stdout (no file written).
# =============================================================================

set -euo pipefail

if ! command -v tree &>/dev/null; then
  echo "Error: tree CLI not found. Install with: brew install tree (macOS) or apt install tree (Linux)" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: tree-report.sh <dir> [<dir> ...]" >&2
  exit 1
fi

FIRST=true
for dir in "$@"; do
  # Resolve to absolute path
  if [[ "${dir}" = /* ]]; then
    abs_dir="${dir}"
  else
    abs_dir="$(cd "$(pwd)" && realpath "${dir}" 2>/dev/null || echo "$(pwd)/${dir}")"
  fi

  if [[ ! -d "${abs_dir}" ]]; then
    echo "Error: not a directory: ${dir}" >&2
    exit 1
  fi

  if [[ "${FIRST}" != "true" ]]; then
    echo ""
  fi
  FIRST=false

  echo "## Tree: ${abs_dir}"
  echo ""
  echo '```text'
  tree -a --dirsfirst --charset=ASCII "${abs_dir}"
  echo '```'
done

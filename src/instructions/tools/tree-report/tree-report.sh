#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/tree-report/tree-report.sh
# CLI wrapper for the tree-report tool — runs `tree` on one or more directories
# and outputs markdown or JSON to stdout.
#
# Usage:
#   tree-report.sh src/components                    # single dir, markdown
#   tree-report.sh src/components src/utils          # multiple dirs, markdown
#   tree-report.sh --markdown src/components         # explicit markdown
#   tree-report.sh --json src/components             # JSON output
#   tree-report.sh --format json src/components      # explicit --format flag
#
# Each directory gets its own section in the output.
# Defaults:
#   --format: markdown (shell default; JS tool defaults to json)
# =============================================================================

set -euo pipefail

if ! command -v tree &>/dev/null; then
  echo "Error: tree CLI not found. Install with: brew install tree (macOS) or apt install tree (Linux)" >&2
  exit 1
fi

# Parse args: extract --format/--markdown/--json, collect remaining as dirs
FORMAT="markdown"
DIRS=()
NEXT_IS_FORMAT=false
for arg in "$@"; do
  if $NEXT_IS_FORMAT; then
    FORMAT="${arg}"
    NEXT_IS_FORMAT=false
  elif [[ "${arg}" == "--format" ]]; then
    NEXT_IS_FORMAT=true
  elif [[ "${arg}" == "--markdown" ]]; then
    FORMAT="markdown"
  elif [[ "${arg}" == "--json" ]]; then
    FORMAT="json"
  else
    DIRS+=("${arg}")
  fi
done

if [[ ${#DIRS[@]} -eq 0 ]]; then
  echo "Usage: tree-report.sh [--markdown|--json|--format markdown|json] <dir> [<dir> ...]" >&2
  exit 1
fi

# Resolve directories and collect tree output
declare -a RESOLVED_DIRS=()
declare -a TREE_OUTPUTS=()
for dir in "${DIRS[@]}"; do
  if [[ "${dir}" = /* ]]; then
    abs_dir="${dir}"
  else
    abs_dir="$(realpath "${dir}" 2>/dev/null || echo "$(pwd)/${dir}")"
  fi

  if [[ ! -d "${abs_dir}" ]]; then
    echo "Error: not a directory: ${dir}" >&2
    exit 1
  fi

  RESOLVED_DIRS+=("${abs_dir}")
  TREE_OUTPUTS+=("$(tree -a --dirsfirst --charset=ASCII "${abs_dir}")")
done

if [[ "${FORMAT}" == "json" ]]; then
  # Build JSON array of {path, tree} objects
  python3 - "${RESOLVED_DIRS[@]}" <<'PYEOF'
import sys, json, subprocess

dirs = sys.argv[1:]
results = []
for d in dirs:
    try:
        out = subprocess.check_output(
            ["tree", "-a", "--dirsfirst", "--charset=ASCII", d],
            text=True, stderr=subprocess.DEVNULL
        )
    except subprocess.CalledProcessError as e:
        out = e.output or ""
    results.append({"path": d, "tree": out.rstrip()})

print(json.dumps({"status": "ok", "directories": results}, indent=2))
PYEOF
else
  # Markdown output
  FIRST=true
  for i in "${!RESOLVED_DIRS[@]}"; do
    if [[ "${FIRST}" != "true" ]]; then
      echo ""
    fi
    FIRST=false

    echo "## Tree: ${RESOLVED_DIRS[$i]}"
    echo ""
    echo '```text'
    echo "${TREE_OUTPUTS[$i]}"
    echo '```'
  done
fi

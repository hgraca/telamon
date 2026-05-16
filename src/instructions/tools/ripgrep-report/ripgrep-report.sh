#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/ripgrep-report/ripgrep-report.sh
# CLI wrapper for the ripgrep-report tool.
#
# Searches the codebase for one or more keywords/phrases and returns the
# 10 most relevant folders ranked by match density.
#
# Usage:
#   ripgrep-report.sh [--format markdown|json] [--root <dir>] <word|phrase> [...]
#
# Options:
#   --format markdown|json   Output format (default: json)
#   --root <dir>             Root directory to search (default: cwd)
#   --top <n>                Number of top folders to return (default: 10)
#
# Ranking:
#   Each folder is scored by the total number of ripgrep matches across all
#   keywords. Folders with more matches rank higher. Ties broken alphabetically.
#
# Dependencies:
#   rg (ripgrep) — required
#   python3      — required (for JSON assembly and scoring)
# =============================================================================

set -euo pipefail

# ── Dependency check ──────────────────────────────────────────────────────────
if ! command -v rg &>/dev/null; then
  echo "Error: ripgrep (rg) not found. Install with: brew install ripgrep (macOS) or apt install ripgrep (Linux)" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 not found." >&2
  exit 1
fi

# ── Argument parsing ──────────────────────────────────────────────────────────
FORMAT="json"
ROOT=""
TOP=10
KEYWORDS=()
NEXT_IS_FORMAT=false
NEXT_IS_ROOT=false
NEXT_IS_TOP=false

for arg in "$@"; do
  if $NEXT_IS_FORMAT; then
    FORMAT="${arg}"
    NEXT_IS_FORMAT=false
  elif $NEXT_IS_ROOT; then
    ROOT="${arg}"
    NEXT_IS_ROOT=false
  elif $NEXT_IS_TOP; then
    TOP="${arg}"
    NEXT_IS_TOP=false
  elif [[ "${arg}" == "--format" ]]; then
    NEXT_IS_FORMAT=true
  elif [[ "${arg}" == "--root" ]]; then
    NEXT_IS_ROOT=true
  elif [[ "${arg}" == "--top" ]]; then
    NEXT_IS_TOP=true
  elif [[ "${arg}" == "--json" ]]; then
    FORMAT="json"
  elif [[ "${arg}" == "--markdown" ]]; then
    FORMAT="markdown"
  else
    KEYWORDS+=("${arg}")
  fi
done

if [[ ${#KEYWORDS[@]} -eq 0 ]]; then
  echo "Usage: ripgrep-report.sh [--format markdown|json] [--root <dir>] [--top <n>] <keyword> [<keyword> ...]" >&2
  exit 1
fi

# Resolve root directory
if [[ -z "${ROOT}" ]]; then
  ROOT="$(pwd)"
fi
ROOT="$(realpath "${ROOT}")"

if [[ ! -d "${ROOT}" ]]; then
  echo "Error: root directory not found: ${ROOT}" >&2
  exit 1
fi

# ── Search and score ──────────────────────────────────────────────────────────
# For each keyword, run rg and collect (folder, match_count) pairs.
# We use rg --count-matches to get per-file match counts, then aggregate by folder.

python3 - "${ROOT}" "${TOP}" "${FORMAT}" "${KEYWORDS[@]}" <<'PYEOF'
import sys
import subprocess
import json
import os
from collections import defaultdict

root   = sys.argv[1]
top_n  = int(sys.argv[2])
fmt    = sys.argv[3]
keywords = sys.argv[4:]

# folder -> {keyword -> match_count, total}
folder_scores: dict[str, dict] = defaultdict(lambda: {"total": 0, "keywords": defaultdict(int)})

for kw in keywords:
    try:
        result = subprocess.run(
            [
                "rg",
                "--count-matches",   # print match count per file
                "--no-heading",
                "--no-messages",
                "--ignore-case",
                "--glob", "!.git",
                "--glob", "!node_modules",
                "--glob", "!vendor",
                "--glob", "!*.lock",
                "--glob", "!*.min.js",
                "--glob", "!*.min.css",
                kw,
                root,
            ],
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        print("Error: rg not found", file=sys.stderr)
        sys.exit(1)

    for line in result.stdout.splitlines():
        # format: /abs/path/to/file:count
        if ":" not in line:
            continue
        parts = line.rsplit(":", 1)
        if len(parts) != 2:
            continue
        filepath, count_str = parts
        try:
            count = int(count_str)
        except ValueError:
            continue

        folder = os.path.dirname(filepath)
        # Normalise: make relative to root
        try:
            rel_folder = os.path.relpath(folder, root)
        except ValueError:
            rel_folder = folder

        folder_scores[rel_folder]["total"] += count
        folder_scores[rel_folder]["keywords"][kw] += count

# Sort by total descending, then alphabetically
ranked = sorted(
    folder_scores.items(),
    key=lambda x: (-x[1]["total"], x[0]),
)[:top_n]

if fmt == "json":
    output = {
        "status": "ok",
        "root": root,
        "keywords": keywords,
        "top_folders": [
            {
                "rank": i + 1,
                "folder": folder,
                "total_matches": data["total"],
                "matches_by_keyword": dict(data["keywords"]),
            }
            for i, (folder, data) in enumerate(ranked)
        ],
    }
    print(json.dumps(output, indent=2))
else:
    # Markdown output
    print(f"## Ripgrep Report")
    print(f"")
    print(f"**Root:** `{root}`  ")
    print(f"**Keywords:** {', '.join(f'`{k}`' for k in keywords)}")
    print(f"")
    if not ranked:
        print("_No matches found._")
    else:
        print(f"| Rank | Folder | Total Matches | Per Keyword |")
        print(f"|------|--------|---------------|-------------|")
        for i, (folder, data) in enumerate(ranked):
            per_kw = ", ".join(f"`{k}`: {v}" for k, v in data["keywords"].items())
            print(f"| {i+1} | `{folder}` | {data['total']} | {per_kw} |")

PYEOF

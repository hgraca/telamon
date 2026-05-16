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
#   --format markdown|json   Output format (default: markdown)
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
FORMAT="markdown"
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

# Resolve root directory, then narrow to src/ or app/ if present
if [[ -z "${ROOT}" ]]; then
  ROOT="$(pwd)"
fi
ROOT="$(realpath "${ROOT}")"

if [[ ! -d "${ROOT}" ]]; then
  echo "Error: root directory not found: ${ROOT}" >&2
  exit 1
fi

if [[ -d "${ROOT}/src" ]]; then
  ROOT="${ROOT}/src"
elif [[ -d "${ROOT}/app" ]]; then
  ROOT="${ROOT}/app"
fi

# ── Search and score ──────────────────────────────────────────────────────────
# For each keyword, run rg and collect (folder, match_count) pairs.
# Folders whose path contains a keyword receive a 3x score bonus.
# For markdown output, table columns are aligned via format-md.py.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FMT_SCRIPT="${SCRIPT_DIR}/../format-md/format-md.py"

# Always capture python output; for markdown we post-process with format-md.
TMP_OUT="$(mktemp /tmp/ripgrep-report-XXXXXX)"
trap 'rm -f "${TMP_OUT}"' EXIT

python3 - "${ROOT}" "${TOP}" "${FORMAT}" "${KEYWORDS[@]}" > "${TMP_OUT}" <<'PYEOF'
import sys
import subprocess
import json
import os
from collections import defaultdict

root     = sys.argv[1]
top_n    = int(sys.argv[2])
fmt      = sys.argv[3]
keywords = sys.argv[4:]

# folder -> {total, keywords: {kw: count}}
folder_scores: dict[str, dict] = defaultdict(lambda: {"total": 0, "keywords": defaultdict(int)})

for kw in keywords:
    try:
        result = subprocess.run(
            [
                "rg",
                "--count-matches",
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
        try:
            rel_folder = os.path.relpath(folder, root)
        except ValueError:
            rel_folder = folder
        folder_scores[rel_folder]["total"] += count
        folder_scores[rel_folder]["keywords"][kw] += count

# Path-name bonus: folders whose path contains a keyword get 3x score.
# This surfaces architecturally-named folders above high-volume generic ones.
PATH_BONUS = 3.0

def effective_score(folder: str, data: dict) -> float:
    base = data["total"]
    folder_lower = folder.lower()
    for kw in keywords:
        if kw.lower() in folder_lower:
            return base * PATH_BONUS
    return float(base)

ranked = sorted(
    folder_scores.items(),
    key=lambda x: (-effective_score(x[0], x[1]), x[0]),
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
                "score": round(effective_score(folder, data), 1),
                "path_bonus": any(kw.lower() in folder.lower() for kw in keywords),
                "matches_by_keyword": dict(data["keywords"]),
            }
            for i, (folder, data) in enumerate(ranked)
        ],
    }
    print(json.dumps(output, indent=2))
else:
    print("## Ripgrep Report")
    print("")
    print(f"**Root:** `{root}`  ")
    print(f"**Keywords:** {', '.join(f'`{k}`' for k in keywords)}")
    print("")
    if not ranked:
        print("_No matches found._")
    else:
        print("| Rank | Folder | Score | Matches | Per Keyword |")
        print("|------|--------|-------|---------|-------------|")
        for i, (folder, data) in enumerate(ranked):
            per_kw = ", ".join(f"`{k}`: {v}" for k, v in data["keywords"].items())
            score  = effective_score(folder, data)
            star   = " ★" if any(kw.lower() in folder.lower() for kw in keywords) else ""
            print(f"| {i+1} | `{folder}`{star} | {score:.0f} | {data['total']} | {per_kw} |")

PYEOF

# For markdown: align table columns, then print. For JSON: print as-is.
if [[ "${FORMAT}" == "markdown" && -f "${FMT_SCRIPT}" ]]; then
  python3 "${FMT_SCRIPT}" "${TMP_OUT}" >/dev/null 2>&1
fi
cat "${TMP_OUT}"

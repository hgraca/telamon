#!/usr/bin/env python3
"""gather-context-from-code — gather code context for a set of words/sentences.

Orchestrates graphify-report to find the most relevant files and folders,
then runs tree on the deduplicated coarse folders.

Steps:
  1. Run graphify-report with the given words → get top_file_nodes + top_folder_nodes
  2. Extract top 10 file paths from top_file_nodes
  3. Extract top 10 folder paths from top_folder_nodes
     - Remove overlapping folders, keeping the most coarse (shortest path) only
  4. Run tree on the deduplicated folders
  5. Output: file list + folder list + tree(s)

Usage:
  python3 gather-context-from-code.py planning workflow
  python3 gather-context-from-code.py "memory skill" --format json
  python3 gather-context-from-code.py planning --graph-path graphify-out/graph.json
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def find_telamon_root(start: Path) -> Path:
    p = start.resolve()
    for _ in range(10):
        if (p / "src" / "instructions" / "tools").is_dir():
            return p
        p = p.parent
    return start.resolve()


SCRIPT_DIR = Path(__file__).resolve().parent
TELAMON_ROOT = find_telamon_root(SCRIPT_DIR)
TOOLS_DIR = TELAMON_ROOT / "src" / "instructions" / "tools"


def run_graphify_report(words: str, graph_path: str, top_n: int) -> dict:
    script = TOOLS_DIR / "graphify-report" / "graphify-report.py"
    cmd = [
        "python3", str(script),
        "--graph-path", graph_path,
        "--words", words,
        "--top-n", str(top_n),
        "--format", "json",
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"graphify-report failed: {proc.stderr.strip() or proc.stdout.strip()}")
    return json.loads(proc.stdout.strip())


def deduplicate_folders(folders: list[str]) -> list[str]:
    """Remove overlapping folders, keeping the most coarse (shortest path prefix) only."""
    if not folders:
        return []
    # Sort by path length ascending (coarsest first)
    sorted_folders = sorted(folders, key=lambda f: len(f.split("/")))
    kept = []
    for folder in sorted_folders:
        # Keep this folder only if no already-kept folder is a prefix of it
        dominated = any(
            folder == k or folder.startswith(k.rstrip("/") + "/")
            for k in kept
        )
        if not dominated:
            kept.append(folder)
    return kept


def run_tree(folder: str, project_root: Path) -> str:
    """Run tree on a folder path (relative to project_root or absolute)."""
    if os.path.isabs(folder):
        abs_folder = folder
    else:
        abs_folder = str(project_root / folder)

    if not os.path.isdir(abs_folder):
        return f"(directory not found: {abs_folder})"

    try:
        result = subprocess.run(
            ["tree", "-a", "--dirsfirst", "--charset=ASCII", abs_folder],
            capture_output=True, text=True,
        )
        return result.stdout.rstrip()
    except FileNotFoundError:
        return "(tree command not found — install with: brew install tree or apt install tree)"


def main() -> None:
    parser = argparse.ArgumentParser(description="gather-context-from-code: gather code context for words/sentences")
    parser.add_argument("words", nargs="*", help="Words or sentences to search for (positional)")
    parser.add_argument("--words", dest="words_flag", default="", help="Comma-separated words (alternative to positional)")
    parser.add_argument("--graph-path", default="graphify-out/graph.json", help="Path to graph.json")
    parser.add_argument("--top-n", type=int, default=10, help="Number of top nodes to retrieve (default: 10)")
    parser.add_argument("--format", choices=["markdown", "json"], default="markdown")
    parser.add_argument("--markdown", action="store_true")
    parser.add_argument("--json", action="store_true", dest="json_flag")
    args = parser.parse_args()

    fmt = args.format
    if args.markdown:
        fmt = "markdown"
    if args.json_flag:
        fmt = "json"

    # Combine positional and --words
    positional = list(args.words) if args.words else []
    words_flag = [w.strip() for w in args.words_flag.split(",") if w.strip()]
    all_words = positional + words_flag
    if not all_words:
        print("Error: provide at least one word or sentence.", file=sys.stderr)
        sys.exit(1)

    words_str = ",".join(all_words)
    project_root = Path(os.getcwd())

    # 1. Run graphify-report
    try:
        report = run_graphify_report(words_str, args.graph_path, args.top_n)
    except RuntimeError as e:
        msg = str(e)
        if fmt == "json":
            print(json.dumps({"status": "error", "message": msg}))
        else:
            print(f"❌ {msg}")
        sys.exit(1)

    # 2. Extract top file paths (deduplicated, preserving rank order)
    file_nodes = report.get("top_file_nodes", [])
    seen_paths: set[str] = set()
    file_paths: list[str] = []
    for n in file_nodes:
        src = n.get("source", "")
        if src and src not in seen_paths:
            seen_paths.add(src)
            file_paths.append(src)

    # 3. Extract top folder paths and deduplicate
    folder_nodes = report.get("top_folder_nodes", [])
    raw_folders = [n["folder"] for n in folder_nodes if n.get("folder") and n["folder"] != "."]
    deduped_folders = deduplicate_folders(raw_folders)

    # 4. Run tree on each deduplicated folder
    trees: list[dict] = []
    for folder in deduped_folders:
        tree_output = run_tree(folder, project_root)
        trees.append({"folder": folder, "tree": tree_output})

    # 5. Output
    if fmt == "json":
        print(json.dumps({
            "status": "ok",
            "query": words_str,
            "top_file_paths": file_paths,
            "top_folders": deduped_folders,
            "trees": trees,
        }, indent=2))
    else:
        parts = [f"# Code Context: `{words_str}`", ""]

        # File nodes section
        parts.append("## Top Relevant Files")
        parts.append("")
        if file_paths:
            for i, fp in enumerate(file_paths, 1):
                parts.append(f"{i}. `{fp}`")
        else:
            parts.append("_No matching file nodes found._")
        parts.append("")

        # Folder nodes section
        parts.append("## Top Relevant Folders")
        parts.append("")
        if deduped_folders:
            for i, folder in enumerate(deduped_folders, 1):
                parts.append(f"{i}. `{folder}`")
        else:
            parts.append("_No matching folder nodes found._")
        parts.append("")

        # Tree sections
        if trees:
            parts.append("## Directory Trees")
            parts.append("")
            for t in trees:
                parts.append(f"### `{t['folder']}`")
                parts.append("")
                parts.append("```text")
                parts.append(t["tree"])
                parts.append("```")
                parts.append("")

        print("\n".join(parts))


if __name__ == "__main__":
    main()

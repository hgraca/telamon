#!/usr/bin/env python3
"""gather-context — gather memory + codebase context for a set of keywords.

Orchestrates three tools in sequence:
  1. qmd-report   — search memory vault for relevant notes/decisions
  2. graphify-report — find most-connected nodes matching keywords, extract folders
  3. tree-report  — show directory trees for the relevant folders

Usage:
  python3 gather-context.py planning workflow
  python3 gather-context.py --keywords "planning,workflow"
  python3 gather-context.py planning --format json
  python3 gather-context.py planning --markdown
  python3 gather-context.py planning --json
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def find_telamon_root(start: Path) -> Path:
    """Walk up from start until we find src/instructions/tools/."""
    p = start.resolve()
    for _ in range(10):
        if (p / "src" / "instructions" / "tools").is_dir():
            return p
        p = p.parent
    return start.resolve()


SCRIPT_DIR = Path(__file__).resolve().parent
TELAMON_ROOT = find_telamon_root(SCRIPT_DIR)
TOOLS_DIR = TELAMON_ROOT / "src" / "instructions" / "tools"


def run_script(cmd: list[str], extra_env: dict | None = None) -> tuple[str, int]:
    env = {**os.environ}
    if extra_env:
        env.update(extra_env)
    proc = subprocess.run(cmd, capture_output=True, text=True, env=env)
    return proc.stdout, proc.returncode


def run_qmd(keywords: list[str], collection: str, max_results: int) -> dict:
    script = TOOLS_DIR / "qmd-report" / "qmd-report.py"
    cmd = [
        "python3", str(script),
        "--format", "json",
        "--collection", collection,
        "--max-results", str(max_results),
    ]
    for kw in keywords:
        cmd += ["--query", kw]
    env = {"XDG_CACHE_HOME": str(TELAMON_ROOT / "storage"), "QMD_LLAMA_GPU": "true"}
    out, code = run_script(cmd, env)
    if code != 0:
        return {"status": "error", "code": "QMD_FAILED", "output": out}
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return {"status": "error", "code": "QMD_PARSE_ERROR", "output": out}


def run_graphify(keywords: list[str], top_n: int, graph_path: str) -> dict:
    script = TOOLS_DIR / "graphify-report" / "graphify-report.py"
    words = ",".join(keywords)
    cmd = [
        "python3", str(script),
        "--graph-path", graph_path,
        "--top-n", str(top_n),
        "--format", "json",
        "--words", words,
    ]
    out, code = run_script(cmd)
    if code != 0:
        return {"status": "error", "code": "GRAPHIFY_FAILED", "output": out}
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return {"status": "error", "code": "GRAPHIFY_PARSE_ERROR", "output": out}


def extract_relevant_folders(graphify_data: dict, project_root: Path) -> list[str]:
    """Extract unique parent folders from graphify word_matches and god_nodes source files."""
    folders: set[str] = set()

    def add_source(source: str) -> None:
        if not source:
            return
        # source_file is relative to project root
        p = Path(source)
        # Take the parent directory (or the path itself if it's already a dir)
        folder = str(p.parent) if p.suffix else str(p)
        if folder and folder != ".":
            folders.add(folder)

    # Word matches (most relevant — directly keyword-matched)
    word_matches = graphify_data.get("word_matches", {}).get("matches", [])
    for m in word_matches:
        add_source(m.get("source", ""))
        for nb in m.get("neighbors", []):
            add_source(nb.get("source", ""))

    # God nodes (most connected — always useful for orientation)
    for g in graphify_data.get("god_nodes", []):
        add_source(g.get("source", ""))

    # Filter to folders that actually exist under project root
    valid: list[str] = []
    for f in sorted(folders):
        abs_f = project_root / f
        if abs_f.is_dir():
            valid.append(f)

    return valid


def run_tree(folders: list[str], project_root: Path) -> dict:
    script = TOOLS_DIR / "tree-report" / "tree-report.sh"
    abs_folders = [str(project_root / f) for f in folders]
    cmd = ["bash", str(script), "--json"] + abs_folders
    out, code = run_script(cmd)
    if code != 0:
        return {"status": "error", "code": "TREE_FAILED", "output": out}
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return {"status": "error", "code": "TREE_PARSE_ERROR", "output": out}


# ---------------------------------------------------------------------------
# Markdown formatters
# ---------------------------------------------------------------------------

def md_section(title: str, body: str) -> str:
    return f"# {title}\n\n{body}\n"


def format_qmd_md(qmd_data: dict) -> str:
    if qmd_data.get("status") == "error":
        return f"_QMD error: {qmd_data.get('code')} — {qmd_data.get('output', '')}_\n"
    results = qmd_data.get("results", [])
    if not results:
        return "_No memory vault matches found._\n"
    lines = []
    for r in results:
        path = r.get("path", "")
        score = r.get("score", "")
        content = r.get("content", "").strip()
        lines.append(f"## {path} (score: {score})\n\n{content}\n")
    return "\n".join(lines)


def format_graphify_md(graphify_data: dict, folders: list[str]) -> str:
    if graphify_data.get("status") == "error":
        return f"_Graphify error: {graphify_data.get('code')} — {graphify_data.get('output', '')}_\n"

    lines = []

    # Stats
    stats = graphify_data.get("stats", {})
    if stats:
        lines += [
            "## Graph Summary",
            "",
            f"| Metric | Value |",
            f"|--------|-------|",
            f"| Nodes | {stats.get('total_nodes', '?')} |",
            f"| Edges | {stats.get('total_edges', '?')} |",
            f"| Communities | {stats.get('total_communities', '?')} |",
            "",
        ]

    # Relevant folders
    if folders:
        lines += ["## Relevant Folders", ""]
        for f in folders:
            lines.append(f"- `{f}`")
        lines.append("")

    # Word matches summary
    wm = graphify_data.get("word_matches", {})
    matches = wm.get("matches", [])
    if matches:
        lines += [f"## Keyword Matches ({wm.get('total_matches', len(matches))} nodes)", ""]
        for m in matches[:10]:  # cap at 10 for readability
            label = m.get("label", "")
            source = m.get("source", "")
            degree = m.get("degree", "")
            lines.append(f"- **{label}** · `{source}` · degree={degree}")
        lines.append("")

    return "\n".join(lines)


def format_tree_md(tree_data: dict) -> str:
    if tree_data.get("status") == "error":
        return f"_Tree error: {tree_data.get('code')} — {tree_data.get('output', '')}_\n"
    directories = tree_data.get("directories", [])
    if not directories:
        return "_No directory trees available._\n"
    lines = []
    for d in directories:
        path = d.get("path", "")
        tree = d.get("tree", "")
        lines += [f"## Tree: {path}", "", "```text", tree, "```", ""]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def resolve_collection(project_root: Path) -> str:
    config = project_root / ".ai" / "telamon" / "telamon.jsonc"
    try:
        raw = config.read_text()
        data = json.loads(raw)
        return data.get("project_name", "telamon")
    except Exception:
        return "telamon"


def main() -> None:
    parser = argparse.ArgumentParser(description="gather-context: gather memory + codebase context")
    parser.add_argument(
        "keywords",
        nargs="*",
        help="Keywords to search for (positional)",
    )
    parser.add_argument(
        "--keywords",
        dest="keywords_flag",
        default="",
        help="Comma-separated keywords (alternative to positional args)",
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="json",
        help="Output format (default: json)",
    )
    parser.add_argument("--markdown", action="store_true", help="Force markdown output")
    parser.add_argument("--json", action="store_true", dest="json_flag", help="Force JSON output")
    parser.add_argument(
        "--top-n",
        type=int,
        default=10,
        help="Number of top god nodes from graphify (default: 10)",
    )
    parser.add_argument(
        "--max-results",
        type=int,
        default=5,
        help="Max QMD results (default: 5)",
    )
    parser.add_argument(
        "--graph-path",
        default="graphify-out/graph.json",
        help="Path to graph.json (default: graphify-out/graph.json)",
    )
    parser.add_argument(
        "--collection",
        default="",
        help="QMD collection name (default: auto-detected from telamon.jsonc)",
    )
    args = parser.parse_args()

    # Resolve format
    fmt = args.format
    if args.markdown:
        fmt = "markdown"
    if args.json_flag:
        fmt = "json"

    # Collect keywords
    keywords: list[str] = list(args.keywords)
    if args.keywords_flag:
        keywords += [k.strip() for k in args.keywords_flag.split(",") if k.strip()]
    if not keywords:
        print(
            json.dumps({"status": "error", "code": "NO_KEYWORDS", "message": "Provide at least one keyword"})
            if fmt == "json"
            else "Error: provide at least one keyword.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Resolve project root (CWD when invoked from project)
    project_root = Path(os.getcwd())
    collection = args.collection or resolve_collection(project_root)

    # 1. QMD
    qmd_data = run_qmd(keywords, collection, args.max_results)

    # 2. Graphify
    graphify_data = run_graphify(keywords, args.top_n, args.graph_path)

    # 3. Extract folders from graphify output
    folders = extract_relevant_folders(graphify_data, project_root)

    # 4. Tree (only if we have folders)
    tree_data: dict = {"status": "ok", "directories": []}
    if folders:
        tree_data = run_tree(folders, project_root)

    # Output
    if fmt == "json":
        result = {
            "status": "ok",
            "keywords": keywords,
            "relevant_folders": folders,
            "memory": qmd_data,
            "graph": graphify_data,
            "trees": tree_data,
        }
        print(json.dumps(result, indent=2))
    else:
        parts = [
            f"# Context Priming: {', '.join(keywords)}",
            "",
            "---",
            "",
            md_section("Memory Vault", format_qmd_md(qmd_data)),
            md_section("Codebase Graph", format_graphify_md(graphify_data, folders)),
            md_section("Directory Trees", format_tree_md(tree_data)),
        ]
        print("\n".join(parts))


if __name__ == "__main__":
    main()

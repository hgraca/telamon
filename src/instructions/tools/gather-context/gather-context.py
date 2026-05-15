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
from collections import defaultdict
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


# ---------------------------------------------------------------------------
# Folder auto-collapse
# ---------------------------------------------------------------------------

def auto_collapse_folders(raw_folders: list[str], project_root: Path) -> list[str]:
    """Return the minimal set of ancestor dirs that cover all raw_folders.

    Algorithm:
      1. Collect all valid leaf dirs (exist on disk).
      2. Build a coverage map: ancestor → set of leaf indices it covers.
      3. For each leaf, find its deepest ancestor that covers ≥2 leaves
         (i.e. shares at least one sibling leaf). That is the tightest
         meaningful grouping for that leaf.
      4. Collect unique best-ancestors as candidates.
      5. Remove any candidate that is a strict child of another candidate
         (the parent already covers it — prefer the shallower grouping).
      6. Return sorted list of candidates that exist on disk.
    """
    leaves: list[Path] = []
    for f in raw_folders:
        abs_f = project_root / f
        if abs_f.is_dir():
            leaves.append(Path(f))

    if not leaves:
        return []
    if len(leaves) == 1:
        return [str(leaves[0])]

    # Build coverage map
    ancestor_coverage: dict[str, set[int]] = defaultdict(set)
    for idx, leaf in enumerate(leaves):
        parts = leaf.parts
        for depth in range(1, len(parts) + 1):
            ancestor = str(Path(*parts[:depth]))
            ancestor_coverage[ancestor].add(idx)

    # For each leaf, find its deepest ancestor covering ≥2 leaves
    leaf_best: dict[int, str] = {}
    for idx, leaf in enumerate(leaves):
        parts = leaf.parts
        best = str(leaf)  # fallback: unique leaf kept as-is
        for depth in range(len(parts), 0, -1):
            ancestor = str(Path(*parts[:depth]))
            if len(ancestor_coverage[ancestor]) >= 2:
                best = ancestor
                break
        leaf_best[idx] = best

    candidates: set[str] = set(leaf_best.values())

    # Remove any candidate that is a strict child of another candidate
    final: set[str] = set()
    for c in candidates:
        has_ancestor_in_candidates = any(
            c != other and c.startswith(other + os.sep)
            for other in candidates
        )
        if not has_ancestor_in_candidates:
            final.add(c)

    result = [s for s in final if (project_root / s).is_dir()]
    return sorted(result)


# ---------------------------------------------------------------------------
# File relations extraction
# ---------------------------------------------------------------------------

def extract_file_relations(graphify_data: dict) -> list[dict]:
    """Extract file-to-file relations from graphify word_matches.

    Returns list of {from_file, relation, to_file} dicts, deduplicated,
    sorted by from_file then relation.
    """
    word_matches = graphify_data.get("word_matches", {}).get("matches", [])
    seen: set[tuple[str, str, str]] = set()
    relations: list[dict] = []

    for m in word_matches:
        from_file = m.get("source", "")
        if not from_file:
            continue
        for nb in m.get("neighbors", []):
            to_file = nb.get("source", "")
            relation = nb.get("relation", "")
            if not to_file or not relation or to_file == from_file:
                continue
            key = (from_file, relation, to_file)
            if key not in seen:
                seen.add(key)
                relations.append({
                    "from_file": from_file,
                    "relation": relation,
                    "to_file": to_file,
                })

    relations.sort(key=lambda r: (r["from_file"], r["relation"], r["to_file"]))
    return relations


def extract_relevant_folders(graphify_data: dict, project_root: Path) -> list[str]:
    """Extract raw leaf dirs from graphify matches, then auto-collapse."""
    raw: set[str] = set()

    def add_source(source: str) -> None:
        if not source:
            return
        p = Path(source)
        folder = str(p.parent) if p.suffix else str(p)
        if folder and folder != ".":
            raw.add(folder)

    word_matches = graphify_data.get("word_matches", {}).get("matches", [])
    for m in word_matches:
        add_source(m.get("source", ""))
        for nb in m.get("neighbors", []):
            add_source(nb.get("source", ""))

    # Do NOT include god_nodes — they add noise unrelated to the keywords
    return auto_collapse_folders(sorted(raw), project_root)


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
        # QMD JSON schema: file, title, score, snippet (content requires qmd get)
        file_path = r.get("file", "")
        title = r.get("title", "") or file_path
        score = r.get("score", "")
        snippet = r.get("snippet", "").strip()
        header = f"## {title}"
        if file_path and file_path != title:
            header += f" — `{file_path}`"
        score_str = f" (score: {score:.2f})" if isinstance(score, float) else f" (score: {score})"
        lines.append(f"{header}{score_str}")
        lines.append("")
        if snippet:
            lines.append(snippet)
            lines.append("")
    return "\n".join(lines)


def format_relations_md(relations: list[dict], folders: list[str]) -> str:
    """Format file-to-file relations and relevant folders."""
    lines = []

    # Relevant folders (collapsed)
    if folders:
        lines += ["## Relevant Areas", ""]
        for f in folders:
            lines.append(f"- `{f}`")
        lines.append("")

    # File relations
    if relations:
        lines += ["## Code Relations", ""]
        lines += [
            "| From | Relation | To |",
            "|------|----------|----|",
        ]
        for r in relations:
            from_f = r["from_file"].replace("|", "\\|")
            to_f = r["to_file"].replace("|", "\\|")
            rel = r["relation"]
            lines.append(f"| `{from_f}` | {rel} | `{to_f}` |")
        lines.append("")
    elif folders:
        lines += ["## Code Relations", "", "_No inter-file relations found for these keywords._", ""]

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

    # 3. Extract collapsed folders and file relations from graphify output
    folders = extract_relevant_folders(graphify_data, project_root)
    relations = extract_file_relations(graphify_data)

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
            "file_relations": relations,
            "memory": qmd_data,
            "graph": graphify_data,
            "trees": tree_data,
        }
        print(json.dumps(result, indent=2))
    else:
        parts = [
            f"# Gather Context: {', '.join(keywords)}",
            "",
            "---",
            "",
            md_section("Memory Vault", format_qmd_md(qmd_data)),
            md_section("Codebase Graph", format_relations_md(relations, folders)),
            md_section("Directory Trees", format_tree_md(tree_data)),
        ]
        print("\n".join(parts))


if __name__ == "__main__":
    main()

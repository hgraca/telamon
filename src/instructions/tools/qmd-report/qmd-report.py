#!/usr/bin/env python3
"""QMD report tool — searches the project memory vault and returns full file contents as Markdown.

Usage:
  python3 qmd-report.py --query "planning workflow"
  python3 qmd-report.py --query "planning" --query "workflow"
  python3 qmd-report.py --query "planning workflow" --collection my-project --max-results 5
  # Collection defaults to "telamon" if not specified (overridden by TS wrapper which
  # resolves the project name from .ai/telamon/telamon.jsonc)

Output: Markdown with search summary and full file contents for each match.
"""
import json
import subprocess
import sys
import os
import shutil


def _resolve_telamon_root():
    """Resolve TELAMON_ROOT from env or secrets file."""
    root = os.environ.get("TELAMON_ROOT", "")
    if root:
        return root
    # Fallback: try to read from secrets file relative to this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Walk up to find telamon root (src/instructions/tools/qmd-report/ -> ../../..)
    candidate = os.path.abspath(os.path.join(script_dir, "..", "..", ".."))
    secrets_file = os.path.join(candidate, "storage", "secrets", "telamon-root")
    if os.path.isfile(secrets_file):
        with open(secrets_file) as f:
            return f.read().strip()
    return ""


def run_qmd(args):
    """Run qmd CLI and return stdout. Returns None on failure."""
    qmd_path = shutil.which("qmd")
    if not qmd_path:
        return None, "qmd CLI not found. Install with: npm install -g @tobilu/qmd"

    # Set environment for QMD: redirect cache to Telamon storage, enable GPU
    env = os.environ.copy()
    telamon_root = _resolve_telamon_root()
    if telamon_root:
        env["XDG_CACHE_HOME"] = os.path.join(telamon_root, "storage")
    env.setdefault("QMD_LLAMA_GPU", "true")

    try:
        result = subprocess.run(
            [qmd_path] + args,
            capture_output=True,
            text=True,
            timeout=30,
            env=env,
        )
        if result.returncode != 0:
            return None, result.stderr.strip() or result.stdout.strip()
        return result.stdout.strip(), None
    except FileNotFoundError:
        return None, "qmd CLI not found. Install with: npm install -g @tobilu/qmd"
    except subprocess.TimeoutExpired:
        return None, "qmd search timed out after 30s"


def search_qmd(query, collection, max_results):
    """Search QMD and return list of (docid, score, file_uri, title) tuples."""
    cmd = ["search", query, "--json", "--all"]
    if collection:
        cmd += ["-c", collection]

    stdout, err = run_qmd(cmd)
    if err:
        return None, err

    try:
        results = json.loads(stdout)
    except json.JSONDecodeError:
        return None, f"Failed to parse qmd output: {stdout[:500]}"

    if isinstance(results, dict) and results.get("results"):
        results = results["results"]
    elif not isinstance(results, list):
        return None, f"Unexpected qmd output format"

    # Sort by score descending, limit
    results.sort(key=lambda r: r.get("score", 0), reverse=True)
    results = results[:max_results]

    return [
        {
            "docid": r.get("docid", ""),
            "score": r.get("score", 0),
            "file": r.get("file", ""),
            "title": r.get("title", ""),
            "snippet": r.get("snippet", ""),
        }
        for r in results
    ], None


def get_file_content(file_uri):
    """Get full content of a file via qmd get."""
    stdout, err = run_qmd(["get", file_uri])
    if err:
        return None, err
    return stdout, None


def format_markdown(results, query, collection):
    """Format search results as Markdown with full file contents."""
    lines = [
        "# QMD Memory Search",
        "",
        f"Query: `{query}`",
    ]
    if collection:
        lines.append(f"Collection: `{collection}`")
    lines.append(f"Matches: {len(results)}")
    lines.append("")

    if not results:
        lines.append("_No results found._")
        lines.append("")
        return "\n".join(lines)

    # Summary table
    lines.append("## Results Overview")
    lines.append("")
    lines.append("| # | Score | File |")
    lines.append("|---|-------|------|")
    for i, r in enumerate(results, 1):
        file_path = r["file"].replace("|", "\\|")
        lines.append(f"| {i} | {r['score']:.2f} | `{file_path}` |")
    lines.append("")

    # Full contents
    lines.append("## Full Contents")
    lines.append("")

    for i, r in enumerate(results, 1):
        file_uri = r["file"]
        title = r["title"] or file_uri
        lines.append(f"### {i}. {title}")
        lines.append("")
        lines.append(f"**File:** `{file_uri}`  \n**Score:** {r['score']:.2f}")
        lines.append("")

        content, err = get_file_content(file_uri)
        if err:
            lines.append(f"_Error reading file: {err}_")
        elif content:
            lines.append(content)
        else:
            lines.append("_(empty file)_")
        lines.append("")
        lines.append("---")
        lines.append("")

    return "\n".join(lines)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="QMD report tool")
    parser.add_argument(
        "--query",
        action="append",
        required=True,
        help="Search query (can be specified multiple times for multiple words/sentences)",
    )
    parser.add_argument(
        "--collection",
        default="telamon",
        help="QMD collection to search (default: telamon)",
    )
    parser.add_argument(
        "--max-results",
        type=int,
        default=5,
        help="Maximum results per query (default: 5)",
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    args = parser.parse_args()

    # Run searches for each query term
    all_results = []
    seen_files = set()

    for q in args.query:
        results, err = search_qmd(q, args.collection, args.max_results)
        if err:
            if args.format == "json":
                print(json.dumps({"status": "error", "code": "QMD_SEARCH_FAILED", "message": err}))
            else:
                print(f"❌ Search failed for '{q}': {err}")
            sys.exit(1)

        for r in results:
            if r["file"] not in seen_files:
                seen_files.add(r["file"])
                all_results.append(r)

    # Sort combined results by score descending
    all_results.sort(key=lambda r: r["score"], reverse=True)
    all_results = all_results[:args.max_results]

    if args.format == "json":
        output = {
            "status": "ok",
            "query": args.query,
            "collection": args.collection,
            "total_matches": len(all_results),
            "results": all_results,
        }
        print(json.dumps(output, indent=2))
    else:
        print(format_markdown(all_results, ", ".join(args.query), args.collection))


if __name__ == "__main__":
    main()
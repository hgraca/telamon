#!/usr/bin/env python3
"""Codebase Index report tool — searches the codebase by meaning using the codebase-index MCP.

Uses the codebase-index MCP server's codebase_search tool to find code by semantic
meaning, not keywords. Returns full code content for each match.

Usage:
  python3 codebase-index-report.py --query "rate limiter"
  python3 codebase-index-report.py --query "payment handler" --query "auth middleware"
  python3 codebase-index-report.py --query "rate limiter" --max-results 10 --file-type ts

Output: Markdown with search summary and full code contents for each match.
"""
import json
import subprocess
import sys
import os
import shutil


def resolve_telamon_root():
    """Resolve TELAMON_ROOT from env or secrets file."""
    root = os.environ.get("TELAMON_ROOT", "")
    if root:
        return root
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidate = os.path.abspath(os.path.join(script_dir, "..", "..", ".."))
    secrets_file = os.path.join(candidate, "storage", "secrets", "telamon-root")
    if os.path.isfile(secrets_file):
        with open(secrets_file) as f:
            return f.read().strip()
    return ""


def run_codebase_search(query, max_results, file_type, directory):
    """Run codebase-index search via the MCP tool.

    Since the codebase-index is an MCP server (not a CLI), we delegate to a
    small helper script that uses the opencode MCP client to invoke the tool.
    If the MCP bridge is unavailable, we fall back to a grep-based search.
    """
    # Try the MCP bridge first
    mcp_bridge = shutil.which("opencode-mcp-bridge")
    if mcp_bridge:
        return run_mcp_search(mcp_bridge, query, max_results, file_type, directory)

    # Fallback: use ast-grep or ripgrep for keyword-based search
    return run_fallback_search(query, max_results, file_type, directory)


def run_mcp_search(mcp_bridge, query, max_results, file_type, directory):
    """Invoke codebase-index MCP tool via opencode-mcp-bridge."""
    args = {
        "query": query,
        "limit": max_results,
    }
    if file_type:
        args["fileType"] = file_type
    if directory:
        args["directory"] = directory

    try:
        result = subprocess.run(
            [mcp_bridge, "codebase-index", "codebase_search", json.dumps(args)],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            return None, result.stderr.strip() or result.stdout.strip()
        return result.stdout.strip(), None
    except FileNotFoundError:
        return None, "opencode-mcp-bridge not found"
    except subprocess.TimeoutExpired:
        return None, "codebase-index search timed out after 60s"


def run_fallback_search(query, max_results, file_type, directory):
    """Fallback: use ripgrep for keyword-based search when MCP unavailable."""
    # Extract meaningful keywords from the query
    keywords = [w for w in query.split() if len(w) > 2 and w.lower() not in {
        "the", "and", "for", "are", "but", "not", "you", "all", "can", "had",
        "her", "was", "one", "our", "out", "has", "have", "been", "some",
        "them", "than", "what", "when", "where", "which", "will", "with",
    }]

    if not keywords:
        return [], None

    search_dir = directory or os.getcwd()

    # Build rg command: search for any keyword match
    rg_cmd = ["rg", "-l", "-i", "--no-heading"]
    if file_type:
        rg_cmd.extend(["-g", f"*.{file_type}"])
    # Use first keyword as primary pattern, others as additional patterns
    pattern = keywords[0]
    rg_cmd.append(pattern)
    rg_cmd.append(search_dir)

    try:
        result = subprocess.run(
            rg_cmd,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode not in (0, 1):  # 1 = no matches
            return None, f"rg failed: {result.stderr.strip()}"

        files = [f.strip() for f in result.stdout.strip().split("\n") if f.strip()]
        files = files[:max_results]

        results = []
        for filepath in files:
            try:
                with open(filepath) as f:
                    content = f.read()
                results.append({
                    "file": filepath,
                    "score": 1.0,
                    "snippet": content[:500] if len(content) > 500 else content,
                    "content": content,
                })
            except (IOError, OSError):
                continue

        return results, None
    except FileNotFoundError:
        return None, "ripgrep (rg) not found. Install with: apt install ripgrep or brew install ripgrep"
    except subprocess.TimeoutExpired:
        return None, "rg search timed out after 30s"


def format_markdown(results, query, file_type, directory):
    """Format search results as Markdown with full code contents."""
    lines = [
        "# Codebase Index Search",
        "",
        f"Query: `{query}`",
    ]
    if file_type:
        lines.append(f"File type: `{file_type}`")
    if directory:
        lines.append(f"Directory: `{directory}`")
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
        file_path = r.get("file", "").replace("|", "\\|")
        score = r.get("score", 0)
        if isinstance(score, float):
            score_str = f"{score:.2f}"
        else:
            score_str = str(score)
        lines.append(f"| {i} | {score_str} | `{file_path}` |")
    lines.append("")

    # Full contents
    lines.append("## Full Contents")
    lines.append("")

    for i, r in enumerate(results, 1):
        file_uri = r.get("file", "")
        lines.append(f"### {i}. `{file_uri}`")
        lines.append("")
        lines.append(f"**Score:** {r.get('score', 'N/A')}")
        lines.append("")

        content = r.get("content", "")
        if content:
            lines.append("```" + (file_type or ""))
            lines.append(content.rstrip("\n"))
            lines.append("```")
        else:
            snippet = r.get("snippet", "")
            if snippet:
                lines.append("```" + (file_type or ""))
                lines.append(snippet.rstrip("\n"))
                lines.append("```")
                lines.append("")
                lines.append("_(content truncated — use `read` for full file)_")
            else:
                lines.append("_(empty file)_")
        lines.append("")
        lines.append("---")
        lines.append("")

    return "\n".join(lines)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Codebase Index report tool")
    parser.add_argument(
        "--query",
        action="append",
        required=True,
        help="Search query (can be specified multiple times for multiple searches)",
    )
    parser.add_argument(
        "--max-results",
        type=int,
        default=5,
        help="Maximum results per query (default: 5)",
    )
    parser.add_argument(
        "--file-type",
        default="",
        help="Filter by file extension (e.g. 'ts', 'py', 'php')",
    )
    parser.add_argument(
        "--directory",
        default="",
        help="Filter by directory path (e.g. 'src/utils')",
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
        results, err = run_codebase_search(
            q, args.max_results, args.file_type or None, args.directory or None
        )
        if err:
            if args.format == "json":
                print(json.dumps({"status": "error", "code": "SEARCH_FAILED", "message": err}))
            else:
                print(f"❌ Search failed for '{q}': {err}")
            sys.exit(1)

        if results is None:
            continue

        for r in results:
            file_key = r.get("file", "")
            if file_key and file_key not in seen_files:
                seen_files.add(file_key)
                all_results.append(r)

    # Sort by score descending, limit
    all_results.sort(key=lambda r: r.get("score", 0) if isinstance(r.get("score"), (int, float)) else 0, reverse=True)
    all_results = all_results[:args.max_results]

    if args.format == "json":
        output = {
            "status": "ok",
            "query": args.query,
            "file_type": args.file_type or None,
            "directory": args.directory or None,
            "total_matches": len(all_results),
            "results": [
                {
                    "file": r.get("file", ""),
                    "score": r.get("score", 0),
                    "snippet": r.get("snippet", ""),
                }
                for r in all_results
            ],
        }
        print(json.dumps(output, indent=2))
    else:
        print(format_markdown(all_results, ", ".join(args.query), args.file_type, args.directory))


if __name__ == "__main__":
    main()
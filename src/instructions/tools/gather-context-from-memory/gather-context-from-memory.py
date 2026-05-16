#!/usr/bin/env python3
"""gather-context-from-memory — search the memory vault and return full file bodies.

Uses qmd-report to find matching files, then fetches and strips the frontmatter
from each matched file, assembling all bodies into a single output.

Usage:
  python3 gather-context-from-memory.py --query "planning workflow"
  python3 gather-context-from-memory.py --query "planning" --query "workflow"
  python3 gather-context-from-memory.py --query "billing" --collection core --max-results 10
  python3 gather-context-from-memory.py --query "billing" --format json
"""
import argparse
import json
import os
import shutil
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


def _qmd_env() -> dict:
    env = os.environ.copy()
    env["XDG_CACHE_HOME"] = str(TELAMON_ROOT / "storage")
    env.setdefault("QMD_LLAMA_GPU", "true")
    return env


def run_qmd_cli(args: list[str]) -> tuple[str | None, str | None]:
    """Run qmd CLI with given args. Returns (stdout, error_message)."""
    qmd_path = shutil.which("qmd")
    if not qmd_path:
        return None, "qmd CLI not found. Install with: npm install -g @tobilu/qmd"
    try:
        result = subprocess.run(
            [qmd_path] + args,
            capture_output=True,
            text=True,
            timeout=30,
            env=_qmd_env(),
        )
        if result.returncode != 0:
            return None, result.stderr.strip() or result.stdout.strip()
        return result.stdout.strip(), None
    except FileNotFoundError:
        return None, "qmd CLI not found. Install with: npm install -g @tobilu/qmd"
    except subprocess.TimeoutExpired:
        return None, "qmd search timed out after 30s"


def search_qmd(queries: list[str], collection: str, max_results: int) -> tuple[list[dict] | None, str | None]:
    """Run qmd-report.py in JSON mode and return the results list."""
    qmd_report = TELAMON_ROOT / "src" / "instructions" / "tools" / "qmd-report" / "qmd-report.py"
    cmd = [
        "python3", str(qmd_report),
        "--format", "json",
        "--collection", collection,
        "--max-results", str(max_results),
    ]
    for q in queries:
        cmd += ["--query", q]

    proc = subprocess.run(cmd, capture_output=True, text=True, env=_qmd_env())
    if proc.returncode != 0:
        return None, proc.stderr.strip() or proc.stdout.strip()

    try:
        data = json.loads(proc.stdout.strip())
    except json.JSONDecodeError:
        return None, f"Failed to parse qmd-report output: {proc.stdout[:500]}"

    if data.get("status") == "error":
        return None, data.get("message", str(data))

    return data.get("results", []), None


def strip_yaml_frontmatter(content: str) -> str:
    """Strip YAML frontmatter (--- ... ---) from file content."""
    if not content.startswith("---"):
        return content
    end = content.find("\n---", 3)
    if end == -1:
        return content
    return content[end + 4:].lstrip("\n")


def fetch_file_body(file_uri: str) -> tuple[str | None, str | None]:
    """Fetch full file content via `qmd get` and strip frontmatter."""
    stdout, err = run_qmd_cli(["get", file_uri])
    if err:
        return None, err
    return strip_yaml_frontmatter(stdout).strip(), None


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------

def format_markdown(results: list[dict]) -> str:
    if not results:
        return "_No memory vault matches found._\n"
    parts = []
    for r in results:
        file_uri = r.get("file", "")
        if "_body" in r:
            body, err = r["_body"], None
        else:
            body, err = fetch_file_body(file_uri)
        if err:
            parts.append(f"_Error reading file `{file_uri}`: {err}_")
        elif body:
            parts.append(body)
        else:
            parts.append("_(empty file)_")
        parts.append("")
        parts.append("---")
        parts.append("")

    return "\n".join(parts)


def format_json(results: list[dict], queries: list[str], collection: str) -> dict:
    files = []
    for r in results:
        file_uri = r.get("file", "")
        if "_body" in r:
            body, err = r["_body"], None
        else:
            body, err = fetch_file_body(file_uri)
        files.append({
            "file": file_uri,
            "title": r.get("title", ""),
            "score": r.get("score", 0),
            "body": body if body is not None else "",
            "error": err,
        })
    return {
        "status": "ok",
        "query": queries,
        "collection": collection,
        "total_matches": len(files),
        "files": files,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def resolve_collection(project_root: Path) -> str:
    config = project_root / ".ai" / "telamon" / "telamon.jsonc"
    try:
        data = json.loads(config.read_text())
        return data.get("project_name", "telamon")
    except Exception:
        return "telamon"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="gather-context-from-memory: search memory vault and return full file bodies"
    )
    parser.add_argument(
        "--query",
        action="append",
        required=True,
        help="Search query (can be specified multiple times)",
    )
    parser.add_argument(
        "--collection",
        default="",
        help="QMD collection name (default: auto-detected from telamon.jsonc)",
    )
    parser.add_argument(
        "--max-results",
        type=int,
        default=5,
        help="Maximum number of matched files to return (default: 5)",
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    args = parser.parse_args()

    project_root = Path(os.getcwd())
    collection = args.collection or resolve_collection(project_root)
    queries: list[str] = args.query

    results, err = search_qmd(queries, collection, args.max_results)
    if err:
        if args.format == "json":
            print(json.dumps({"status": "error", "code": "QMD_SEARCH_FAILED", "message": err}))
        else:
            print(f"Error: {err}", file=sys.stderr)
        sys.exit(1)

    # Deduplicate: first by file URI, then by body content after fetching.
    # Two distinct files can have identical content (e.g. split vault entries);
    # body-level dedup ensures each unique piece of knowledge appears once.
    seen_uris: set[str] = set()
    seen_bodies: set[str] = set()
    unique_results: list[dict] = []
    for r in results:
        file_uri = r.get("file", "")
        if file_uri in seen_uris:
            continue
        seen_uris.add(file_uri)
        body, _ = fetch_file_body(file_uri)
        body_key = (body or "").strip()
        if body_key and body_key in seen_bodies:
            continue
        if body_key:
            seen_bodies.add(body_key)
        # Attach pre-fetched body so format_markdown doesn't fetch again
        r = dict(r)
        r["_body"] = body
        unique_results.append(r)
    results = unique_results

    if args.format == "json":
        print(json.dumps(format_json(results, queries, collection), indent=2))
    else:
        print(format_markdown(results))


if __name__ == "__main__":
    main()

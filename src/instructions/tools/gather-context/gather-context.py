#!/usr/bin/env python3
"""gather-context — orchestrate context-gathering tools for a set of keywords.

Currently orchestrates:
  1. gather-context-from-memory — search memory vault, return full file bodies

More tools will be added here over time.

Usage:
  python3 gather-context.py planning workflow
  python3 gather-context.py planning --format json
  python3 gather-context.py planning --markdown
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


def run_tool(script: Path, extra_args: list[str]) -> tuple[str, int]:
    env = {**os.environ, "XDG_CACHE_HOME": str(TELAMON_ROOT / "storage"), "QMD_LLAMA_GPU": "true"}
    proc = subprocess.run(["python3", str(script)] + extra_args, capture_output=True, text=True, env=env)
    return proc.stdout, proc.returncode


def resolve_collection(project_root: Path) -> str:
    config = project_root / ".ai" / "telamon" / "telamon.jsonc"
    try:
        return json.loads(config.read_text()).get("project_name", "telamon")
    except Exception:
        return "telamon"


def main() -> None:
    parser = argparse.ArgumentParser(description="gather-context: orchestrate context-gathering tools")
    parser.add_argument("keywords", nargs="*", help="Keywords to search for (positional)")
    parser.add_argument("--format", choices=["markdown", "json"], default="markdown")
    parser.add_argument("--markdown", action="store_true")
    parser.add_argument("--json", action="store_true", dest="json_flag")
    parser.add_argument("--collection", default="")
    parser.add_argument("--max-results", type=int, default=5)
    args = parser.parse_args()

    fmt = args.format
    if args.markdown:
        fmt = "markdown"
    if args.json_flag:
        fmt = "json"

    keywords: list[str] = list(args.keywords)
    if not keywords:
        print("Error: provide at least one keyword.", file=sys.stderr)
        sys.exit(1)

    project_root = Path(os.getcwd())
    collection = args.collection or resolve_collection(project_root)

    # ── 1. gather-context-from-memory ────────────────────────────────────────
    memory_script = TOOLS_DIR / "gather-context-from-memory" / "gather-context-from-memory.py"
    memory_args = [
        "--format", fmt,
        "--collection", collection,
        "--max-results", str(args.max_results),
    ]
    for kw in keywords:
        memory_args += ["--query", kw]

    memory_out, memory_code = run_tool(memory_script, memory_args)

    # ── Output ────────────────────────────────────────────────────────────────
    if fmt == "json":
        result: dict = {}
        if memory_code == 0:
            try:
                result.update(json.loads(memory_out.strip()))
            except json.JSONDecodeError:
                result["memory_error"] = memory_out.strip()
        else:
            result["memory_error"] = memory_out.strip()
        print(json.dumps(result, indent=2))
    else:
        parts = []
        if memory_code == 0 and memory_out.strip():
            parts.append(memory_out.strip())
        elif memory_code != 0:
            parts.append(f"_Memory search failed: {memory_out.strip()}_")
        print("\n\n".join(parts))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Repomix report tool — packages folders with --compress and outputs markdown to stdout.

Uses the repomix CLI to pack one or more directories into markdown output
streamed to stdout, suitable for LLM context windows.

Usage:
  python3 repomix-report.py --dir src/components
  python3 repomix-report.py --dir src/components --dir src/utils
  python3 repomix-report.py --dir src --no-compress

Output: Repomix markdown output streamed to stdout.
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


def run_repomix(directories, compress, include_patterns, ignore_patterns, top_files_length, fmt="markdown"):
    """Run repomix to pack the given directories, outputting markdown or JSON to stdout."""
    repomix_path = shutil.which("repomix")
    if not repomix_path:
        msg = "repomix CLI not found. Install with: npm install -g repomix"
        if fmt == "json":
            print(json.dumps({"status": "error", "code": "REPOMIX_NOT_FOUND", "message": msg}))
        else:
            print(f"❌ {msg}", file=sys.stderr)
        sys.exit(1)

    # repomix takes directories as positional args
    cmd = [repomix_path] + directories

    # Always markdown style from repomix; we wrap in JSON if needed
    cmd.extend(["--style", "markdown", "--stdout"])

    if compress:
        cmd.append("--compress")

    if include_patterns:
        cmd.extend(["--include", include_patterns])

    if ignore_patterns:
        cmd.extend(["--ignore", ignore_patterns])

    if top_files_length:
        cmd.extend(["--top-files-len", str(top_files_length)])

    try:
        if fmt == "json":
            # Capture stdout to wrap in JSON envelope
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120,
            )
            if result.returncode != 0:
                print(json.dumps({
                    "status": "error",
                    "code": "REPOMIX_FAILED",
                    "message": result.stderr.strip(),
                }))
                sys.exit(1)
            print(json.dumps({
                "status": "ok",
                "directories": directories,
                "content": result.stdout,
            }, indent=2))
        else:
            # Stream stdout directly for markdown mode
            result = subprocess.run(
                cmd,
                capture_output=False,
                stdout=sys.stdout,
                stderr=subprocess.PIPE,
                text=True,
                timeout=120,
            )
            if result.returncode != 0:
                print(f"❌ Repomix failed: {result.stderr.strip()}", file=sys.stderr)
                sys.exit(1)
    except FileNotFoundError:
        msg = "repomix CLI not found. Install with: npm install -g repomix"
        if fmt == "json":
            print(json.dumps({"status": "error", "code": "REPOMIX_NOT_FOUND", "message": msg}))
        else:
            print(f"❌ {msg}", file=sys.stderr)
        sys.exit(1)
    except subprocess.TimeoutExpired:
        msg = "repomix packing timed out after 120s"
        if fmt == "json":
            print(json.dumps({"status": "error", "code": "TIMEOUT", "message": msg}))
        else:
            print(f"❌ {msg}", file=sys.stderr)
        sys.exit(1)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Repomix report tool")
    parser.add_argument(
        "--dir",
        action="append",
        required=True,
        help="Directory to pack (can be specified multiple times)",
    )
    parser.add_argument(
        "--no-compress",
        action="store_true",
        help="Disable Tree-sitter compression (default: enabled)",
    )
    parser.add_argument(
        "--include-patterns",
        default="",
        help="Include patterns (glob, comma-separated). E.g. 'src/**/*.js,*.md'",
    )
    parser.add_argument(
        "--ignore-patterns",
        default="",
        help="Ignore patterns (glob, comma-separated). E.g. '*.test.js,docs/**'",
    )
    parser.add_argument(
        "--top-files-length",
        type=int,
        default=10,
        help="Number of largest files to show in metrics (default: 10)",
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    args = parser.parse_args()

    compress = not args.no_compress

    # Resolve directories relative to CWD
    resolved_dirs = []
    for d in args.dir:
        abs_d = os.path.abspath(os.path.join(os.getcwd(), d))
        if not os.path.isdir(abs_d):
            if args.format == "json":
                print(json.dumps({"status": "error", "code": "DIR_NOT_FOUND", "message": f"Directory not found: {d}"}))
            else:
                print(f"❌ Directory not found: {d}", file=sys.stderr)
            sys.exit(1)
        resolved_dirs.append(abs_d)

    run_repomix(
        resolved_dirs,
        compress,
        args.include_patterns or None,
        args.ignore_patterns or None,
        args.top_files_length,
        args.format,
    )


if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
recover-memories-from-brain.py — Re-populate Ogham from curated brain markdown files.

Usage:
    python3 scripts/recover-memories-from-brain.py --project <path> [--profile <name>] [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import textwrap
from pathlib import Path

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

def log(msg: str) -> None:
    """Print progress message to stderr."""
    print(f"[recover-brain] {msg}", file=sys.stderr)


def warn(msg: str) -> None:
    """Print warning to stderr."""
    print(f"[recover-brain] WARNING: {msg}", file=sys.stderr)


# ---------------------------------------------------------------------------
# INI helpers (copied from recover-memories.py)
# ---------------------------------------------------------------------------

def read_ini(cfg_path: Path, key: str) -> str | None:
    """Read a top-level value from a JSONC config file."""
    if not cfg_path.is_file():
        return None
    raw = cfg_path.read_text()
    # Strip // line comments (not inside strings — good enough for simple configs)
    stripped = re.sub(r'(?m)(?<!:)//.*$', '', raw)
    try:
        data = json.loads(stripped)
    except json.JSONDecodeError:
        return None
    val = data.get(key)
    if val is None or val == '':
        return None
    if isinstance(val, bool):
        return 'true' if val else 'false'
    return str(val)


# ---------------------------------------------------------------------------
# Ogham helpers
# ---------------------------------------------------------------------------

def find_ogham() -> str:
    """Return the ogham binary path."""
    result = subprocess.run(["which", "ogham"], capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout.strip()
    return "ogham"


def store_in_ogham(ogham_bin: str, profile: str, tags: str, content: str) -> bool:
    """Store a single memory in Ogham. Returns True on success."""
    try:
        result = subprocess.run(
            [ogham_bin, "store", "--profile", profile, "--tags", tags, content],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            warn(f"ogham store failed: {result.stderr.strip()[:120]}")
            return False
        return True
    except Exception as e:
        warn(f"ogham store exception: {e}")
        return False


# ---------------------------------------------------------------------------
# Brain file parsing
# ---------------------------------------------------------------------------

def strip_frontmatter(text: str) -> str:
    """Remove YAML frontmatter (between --- lines) from the start of text."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != '---':
        return text
    # Find closing ---
    for i, line in enumerate(lines[1:], start=1):
        if line.strip() == '---':
            return '\n'.join(lines[i + 1:])
    return text


def split_into_entries(text: str) -> list[tuple[str, str]]:
    """
    Split text into (header_text, body_text) pairs by ## or ### headers.
    Skips the top-level # Title header.
    Returns list of (title, body) tuples.
    """
    text = strip_frontmatter(text)
    entries: list[tuple[str, str]] = []

    # Split on ## or ### headers (but not # top-level)
    pattern = re.compile(r'^(#{2,3})\s+(.+)$', re.MULTILINE)
    matches = list(pattern.finditer(text))

    for i, match in enumerate(matches):
        title = match.group(2).strip()
        start = match.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[start:end].strip()
        entries.append((title, body))

    return entries


def extract_date(body: str) -> str:
    """Extract date from body text. Supports both formats."""
    # Format: - **Date**: YYYY-MM-DD
    m = re.search(r'-\s*\*\*Date\*\*:\s*(\d{4}-\d{2}-\d{2})', body)
    if m:
        return m.group(1)
    # Format: Date: YYYY-MM-DD
    m = re.search(r'^Date:\s*(\d{4}-\d{2}-\d{2})', body, re.MULTILINE)
    if m:
        return m.group(1)
    return 'unknown'


def extract_category_from_title(title: str) -> str:
    """Extract category from M-<CAT>-NNN: title format."""
    m = re.match(r'M-([A-Z]+)-\d+', title)
    if m:
        return m.group(1)
    return 'FLOW'


def build_content(entry_type: str, title: str, body: str, max_body: int = 500) -> str:
    """Build a one-liner content string for Ogham storage."""
    # Collapse body to single line, truncate
    body_summary = ' '.join(body.split())
    if len(body_summary) > max_body:
        body_summary = body_summary[:max_body]
    return f"{entry_type}: {title} — {body_summary}"


# ---------------------------------------------------------------------------
# Per-file parsers
# ---------------------------------------------------------------------------

def parse_key_decisions(text: str) -> list[tuple[str, str, str]]:
    """Returns list of (title, tags, content)."""
    entries = split_into_entries(text)
    results = []
    for title, body in entries:
        # Skip "See also" sections
        if title.lower().startswith('see also'):
            continue
        content = build_content('decision', title, body)
        tags = 'type:decision,source:brain-recovery'
        results.append((title, tags, content))
    return results


def parse_patterns(text: str) -> list[tuple[str, str, str]]:
    """Returns list of (title, tags, content)."""
    entries = split_into_entries(text)
    results = []
    for title, body in entries:
        if title.lower().startswith('see also'):
            continue
        content = build_content('pattern', title, body)
        tags = 'type:pattern,source:brain-recovery'
        results.append((title, tags, content))
    return results


def parse_gotchas(text: str) -> list[tuple[str, str, str]]:
    """Returns list of (title, tags, content)."""
    entries = split_into_entries(text)
    results = []
    for title, body in entries:
        if title.lower().startswith('see also'):
            continue
        content = build_content('gotcha', title, body)
        tags = 'type:gotcha,source:brain-recovery'
        results.append((title, tags, content))
    return results


def parse_memories(text: str) -> list[tuple[str, str, str]]:
    """Returns list of (title, tags, content). Skips 'See also' sections."""
    entries = split_into_entries(text)
    results = []
    for title, body in entries:
        # Skip "See also" sections
        if title.lower().startswith('see also'):
            continue
        cat = extract_category_from_title(title)
        content = build_content('lesson', title, body)
        tags = f'type:lesson,source:brain-recovery,category:{cat}'
        results.append((title, tags, content))
    return results


# ---------------------------------------------------------------------------
# File dispatch
# ---------------------------------------------------------------------------

BRAIN_FILES: dict[str, tuple[str, object]] = {
    'key_decisions.md': ('key_decisions', parse_key_decisions),
    'patterns.md':      ('patterns',      parse_patterns),
    'gotchas.md':       ('gotchas',       parse_gotchas),
    'memories.md':      ('memories',      parse_memories),
}


def process_brain_file(
    brain_dir: Path,
    filename: str,
    parser_fn: object,
    ogham_bin: str,
    profile: str,
    dry_run: bool,
    start_offset: int = 0,
) -> int:
    """Parse and store entries from one brain file. Returns count stored.

    Args:
        start_offset: Skip this many entries before storing. Use to resume
                      after a partial run (0-indexed, so 64 skips the first 64).
    """
    path = brain_dir / filename
    if not path.is_file():
        warn(f"{filename} not found at {path} — skipping")
        return 0

    text = path.read_text(encoding='utf-8')
    entries = parser_fn(text)  # type: ignore[operator]

    if not entries:
        log(f"No entries found in {filename}")
        return 0

    total = len(entries)
    stored = 0
    skipped = 0

    for i, (title, tags, content) in enumerate(entries, start=1):
        if i <= start_offset:
            skipped += 1
            continue

        if dry_run:
            print(f"  [dry-run] Would store: {content[:120]}", file=sys.stderr)
            stored += 1
        else:
            ok = store_in_ogham(ogham_bin, profile, tags, content)
            if ok:
                stored += 1
            log(f"[recover-brain] Stored {stored}/{total - skipped} entries from {filename} (entry {i}/{total})")

    if skipped:
        log(f"Skipped first {skipped} entries (already recovered)")
    if dry_run:
        log(f"[dry-run] Would store {total - skipped} entries from {filename}")
    else:
        log(f"Stored {stored}/{total - skipped} entries from {filename}")

    return stored


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Re-populate Ogham from curated brain markdown files (no LLM required).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Resume example (continue from entry 65 of patterns.md):
              %(prog)s --project . --start-file patterns.md --start-offset 64
        """),
    )
    parser.add_argument(
        '--project', required=True, metavar='PATH',
        help='Absolute path to the project directory',
    )
    parser.add_argument(
        '--profile', metavar='NAME',
        help='Ogham profile name (defaults to project_name from telamon.jsonc)',
    )
    parser.add_argument(
        '--dry-run', action='store_true',
        help='Parse and show what would be stored without storing',
    )
    parser.add_argument(
        '--start-file', metavar='FILENAME',
        help='Resume from this file (skip earlier files). Must match a brain filename: '
             + ', '.join(BRAIN_FILES.keys()),
    )
    parser.add_argument(
        '--start-offset', type=int, default=0, metavar='N',
        help='Skip the first N entries of --start-file (use when resuming a partial run)',
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    project_dir = Path(args.project).resolve()
    ini_path = project_dir / '.ai' / 'telamon' / 'telamon.jsonc'

    # Resolve profile
    if args.profile:
        profile = args.profile
    else:
        project_name = read_ini(ini_path, 'project_name') or project_dir.name.lower()
        profile = project_name

    brain_dir = project_dir / '.ai' / 'telamon' / 'memory' / 'brain'

    ogham_bin = find_ogham()

    log(f"Project: {project_dir}")
    log(f"Profile: {profile}")
    log(f"Brain dir: {brain_dir}")
    if args.dry_run:
        log("Mode: DRY RUN — no changes will be made")

    totals: dict[str, int] = {}

    # Determine which files to process (handle --start-file)
    start_file = args.start_file
    start_offset = args.start_offset
    skip_remaining_files = bool(start_file)

    if start_file and start_file not in BRAIN_FILES:
        log(f"ERROR: --start-file '{start_file}' not in known files: {list(BRAIN_FILES.keys())}")
        sys.exit(1)

    for filename, (label, parser_fn) in BRAIN_FILES.items():
        # Skip files before --start-file
        if skip_remaining_files:
            if filename == start_file:
                skip_remaining_files = False
                offset = start_offset
            else:
                log(f"Skipping {filename} (before --start-file)")
                totals[filename] = 0
                continue
        else:
            offset = 0

        count = process_brain_file(
            brain_dir=brain_dir,
            filename=filename,
            parser_fn=parser_fn,
            ogham_bin=ogham_bin,
            profile=profile,
            dry_run=args.dry_run,
            start_offset=offset,
        )
        totals[filename] = count

    # Summary
    log("─" * 50)
    log("Summary:")
    grand_total = 0
    for filename, count in totals.items():
        log(f"  {filename}: {count} entries {'(would store)' if args.dry_run else 'stored'}")
        grand_total += count
    log(f"  Total: {grand_total} entries")
    if args.dry_run:
        log("Dry run complete — no changes made.")
    else:
        log("Done.")


if __name__ == '__main__':
    main()

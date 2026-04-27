#!/usr/bin/env python3
"""
recover-memories.py — Extract structured memories from past opencode session transcripts.

Usage:
    python3 scripts/recover-memories.py --project <path> --model <model> [--full] [--dry-run] [--batch-size N] [--db <path>]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

DEFAULT_DB = Path.home() / ".local" / "share" / "opencode" / "opencode.db"
TRACKING_VERSION = 1

EXTRACTION_SYSTEM_PROMPT = """\
You are a knowledge extraction assistant. Analyze the following session transcripts from an AI coding assistant and extract structured memories.

Extract ONLY significant, reusable knowledge — NOT routine operations. Focus on:
- **Decisions**: Architectural or product choices with clear rationale
- **Patterns**: Approaches that worked and should be repeated
- **Gotchas**: Bugs, traps, constraints, or false assumptions that caused problems
- **Lessons**: Reusable takeaways that would help a future developer/agent

Skip trivial file edits, routine test runs, and simple Q&A. Only extract items where the rationale or discovery would be valuable to someone encountering a similar situation.

For each extracted item, include the approximate date (from session metadata) in YYYY-MM-DD format.

For lessons, assign one category:
- ARCH: Architecture decisions, layer boundaries, dependency rules
- TEST: Testing patterns, tooling, strategies
- DOMAIN: Business rules, domain semantics
- ANTI: Approaches that failed — what to do instead
- FLOW: Agent delegation, communication, workflow, tooling

Return your response as a JSON object with this EXACT structure (no markdown, no explanation, ONLY the JSON):
{
  "decisions": [{"decision": "...", "rationale": "...", "date": "YYYY-MM-DD"}],
  "patterns": [{"pattern": "...", "when_to_apply": "...", "date": "YYYY-MM-DD"}],
  "gotchas": [{"problem": "...", "fix_or_workaround": "...", "date": "YYYY-MM-DD"}],
  "lessons": [{"category": "ARCH|TEST|DOMAIN|ANTI|FLOW", "title": "...", "context": "...", "lesson": "...", "scope": "...", "date": "YYYY-MM-DD"}]
}

If a session has nothing significant to extract, return empty arrays for those categories. Never return null.\
"""

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

def log(msg: str) -> None:
    """Print progress message to stderr."""
    print(f"[recover-memories] {msg}", file=sys.stderr)


def warn(msg: str) -> None:
    """Print warning to stderr."""
    print(f"[recover-memories] WARNING: {msg}", file=sys.stderr)


# ---------------------------------------------------------------------------
# INI helpers
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
# opencode CLI discovery
# ---------------------------------------------------------------------------

def find_opencode() -> str:
    """Return the opencode binary path, checking PATH then ~/.opencode/bin/opencode."""
    # Check PATH first
    result = subprocess.run(["which", "opencode"], capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout.strip()
    # Fallback
    fallback = Path.home() / ".opencode" / "bin" / "opencode"
    if fallback.is_file():
        return str(fallback)
    return "opencode"  # let it fail naturally with a clear error


def find_ogham() -> str:
    """Return the ogham binary path."""
    result = subprocess.run(["which", "ogham"], capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout.strip()
    return "ogham"


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def open_db(db_path: Path) -> sqlite3.Connection:
    """Open the opencode SQLite database (read-only)."""
    if not db_path.is_file():
        log(f"ERROR: Database not found at {db_path}")
        sys.exit(1)
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def get_all_session_ids(db_path: Path, project_dir: str) -> set[str]:
    """Get all session IDs for the given project directory."""
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        rows = conn.execute(
            "SELECT id FROM session WHERE directory = ?",
            (project_dir,),
        ).fetchall()
        return {r[0] for r in rows}
    finally:
        conn.close()


def delete_sessions(db_path: Path, session_ids: set[str]) -> None:
    """Delete sessions and their messages/parts from the opencode database."""
    if not session_ids:
        return
    conn = sqlite3.connect(str(db_path))
    try:
        for sid in session_ids:
            try:
                conn.execute(
                    "DELETE FROM part WHERE message_id IN "
                    "(SELECT id FROM message WHERE session_id = ?)",
                    (sid,),
                )
                conn.execute("DELETE FROM message WHERE session_id = ?", (sid,))
                conn.execute("DELETE FROM session WHERE id = ?", (sid,))
            except sqlite3.Error as e:
                warn(f"Failed to delete recovery session {sid}: {e}")
        conn.commit()
        log(f"  Deleted {len(session_ids)} recovery session(s) from opencode DB")
    finally:
        conn.close()


def discover_sessions(conn: sqlite3.Connection, project_dir: str) -> list[dict[str, Any]]:
    """Return all sessions for the given project directory, sorted chronologically."""
    rows = conn.execute(
        "SELECT id, title, directory, time_created FROM session "
        "WHERE directory = ? ORDER BY time_created ASC",
        (project_dir,),
    ).fetchall()
    return [dict(r) for r in rows]


def reconstruct_session(conn: sqlite3.Connection, session_id: str) -> str:
    """
    Reconstruct a session transcript as:
        [user]: text\n\n[assistant]: text\n\n...

    Only text parts are included; tool calls, reasoning, etc. are skipped.
    """
    messages = conn.execute(
        "SELECT id, json_extract(data, '$.role') AS role "
        "FROM message WHERE session_id = ? ORDER BY time_created ASC",
        (session_id,),
    ).fetchall()

    lines: list[str] = []
    for msg in messages:
        msg_id = msg["id"]
        role = msg["role"] or "unknown"

        # Collect text parts for this message
        parts = conn.execute(
            "SELECT json_extract(data, '$.text') AS text "
            "FROM part "
            "WHERE message_id = ? AND json_extract(data, '$.type') = 'text' "
            "ORDER BY time_created ASC",
            (msg_id,),
        ).fetchall()

        text_chunks = [p["text"] for p in parts if p["text"]]
        if not text_chunks:
            continue

        combined = "\n".join(text_chunks).strip()
        if combined:
            lines.append(f"[{role}]: {combined}")

    return "\n\n".join(lines)


# ---------------------------------------------------------------------------
# Tracking file helpers
# ---------------------------------------------------------------------------

def tracking_path(project_dir: Path, project_name: str) -> Path:
    return project_dir / ".ai" / "telamon" / "memory" / "thinking" / f".recover-memories-{project_name}.json"


def load_tracking(path: Path) -> dict[str, Any]:
    if path.is_file():
        try:
            data = json.loads(path.read_text())
            if isinstance(data, dict):
                return data
        except (json.JSONDecodeError, OSError):
            pass
    return {"processed_sessions": [], "last_run": None, "version": TRACKING_VERSION}


def save_tracking(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data["last_run"] = datetime.now(timezone.utc).isoformat()
    data["version"] = TRACKING_VERSION
    path.write_text(json.dumps(data, indent=2))


# ---------------------------------------------------------------------------
# Full reset helpers
# ---------------------------------------------------------------------------

def full_reset_ogham(project_name: str, project_dir: Path, ogham_bin: str) -> None:
    """Export Ogham backup, then delete all memories in the profile."""
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_dir = project_dir / ".ai" / "telamon" / "memory" / "thinking"
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup_file = backup_dir / f"ogham-backup-{timestamp}.json"

    log(f"Exporting Ogham profile '{project_name}' to {backup_file} ...")
    result = subprocess.run(
        [ogham_bin, "export", "--profile", project_name, "--output", str(backup_file), "--format", "json"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        warn(f"Ogham export failed (continuing): {result.stderr.strip()}")
    else:
        log(f"  Backup written to {backup_file}")

    # List all memory IDs
    log("Listing Ogham memories to delete ...")
    result = subprocess.run(
        [ogham_bin, "list", "--profile", project_name, "--json", "--limit", "1000"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        warn(f"Ogham list failed (skipping delete): {result.stderr.strip()}")
        return

    try:
        memories = json.loads(result.stdout)
        if not isinstance(memories, list):
            memories = []
    except json.JSONDecodeError:
        warn("Could not parse Ogham list output — skipping delete")
        return

    log(f"  Deleting {len(memories)} memories ...")
    for mem in memories:
        mem_id = mem.get("id") if isinstance(mem, dict) else None
        if not mem_id:
            continue
        del_result = subprocess.run(
            [ogham_bin, "delete", "--profile", project_name, "--yes", mem_id],
            capture_output=True, text=True,
        )
        if del_result.returncode != 0:
            warn(f"  Failed to delete memory {mem_id}: {del_result.stderr.strip()}")


def find_template(project_dir: Path, filename: str) -> Path | None:
    """Find the brain template file under .opencode/skills/."""
    skills_root = project_dir / ".opencode" / "skills"
    if not skills_root.is_dir():
        return None
    pattern = f"memory-management/_tmpl/brain/{filename}"
    for candidate in skills_root.rglob(f"_tmpl/brain/{filename}"):
        return candidate
    return None


def reset_brain_files(project_dir: Path, project_name: str) -> None:
    """Reset brain/ files to their template versions."""
    brain_dir = project_dir / ".ai" / "telamon" / "memory" / "brain"
    brain_dir.mkdir(parents=True, exist_ok=True)

    today = datetime.now().strftime("%Y-%m-%d")
    filenames = ["key_decisions.md", "patterns.md", "gotchas.md", "memories.md"]

    for filename in filenames:
        tmpl = find_template(project_dir, filename)
        target = brain_dir / filename
        if tmpl and tmpl.is_file():
            content = tmpl.read_text()
            content = content.replace("DATE_PLACEHOLDER", today)
            content = content.replace("PROJECT_NAME", project_name)
            target.write_text(content)
            log(f"  Reset {filename} from template")
        else:
            warn(f"  Template for {filename} not found — preserving existing file")


# ---------------------------------------------------------------------------
# LLM call helpers
# ---------------------------------------------------------------------------

def call_llm(
    opencode_bin: str,
    model: str,
    project_dir: str,
    prompt: str,
) -> str | None:
    """
    Call opencode run with the given prompt and return the assistant's text response.
    Returns None on failure.
    """
    # Write prompt to a temp file to avoid argv length limits
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".txt", delete=False, encoding="utf-8"
    ) as tmp:
        tmp.write(prompt)
        tmp_path = tmp.name

    try:
        result = subprocess.run(
            [
                opencode_bin,
                "run",
                "--model", model,
                "--dir", project_dir,
                "--format", "json",
                "--pure",
                "--dangerously-skip-permissions",
                "--file", tmp_path,
                "--",
                "Extract memories from the attached session transcripts. Return JSON only.",
            ],
            capture_output=True,
            text=True,
            timeout=300,
        )
    except subprocess.TimeoutExpired:
        warn("LLM call timed out after 300s")
        return None
    except FileNotFoundError:
        warn(f"opencode binary not found at '{opencode_bin}'")
        return None
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

    if result.returncode != 0:
        warn(f"opencode run failed (exit {result.returncode}): {result.stderr.strip()[:200]}")
        return None

    # Parse JSON event stream — collect all text events
    # Event format: {"type":"text","part":{"type":"text","text":"..."},...}
    text_parts: list[str] = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict) and event.get("type") == "text":
            part = event.get("part", {})
            t = part.get("text", "") if isinstance(part, dict) else ""
            if t:
                text_parts.append(t)

    return "".join(text_parts) if text_parts else None


def parse_llm_response(raw: str) -> dict[str, Any] | None:
    """
    Parse the LLM response as JSON.
    Strips markdown code fences if present.
    Returns None if parsing fails.
    """
    # Strip markdown code fences
    cleaned = re.sub(r"^```(?:json)?\s*", "", raw.strip(), flags=re.MULTILINE)
    cleaned = re.sub(r"\s*```\s*$", "", cleaned.strip(), flags=re.MULTILINE)
    cleaned = cleaned.strip()

    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        # Try to find a JSON object in the response
        m = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if m:
            try:
                data = json.loads(m.group(0))
            except json.JSONDecodeError:
                return None
        else:
            return None

    if not isinstance(data, dict):
        return None

    # Ensure all expected keys exist and are lists
    for key in ("decisions", "patterns", "gotchas", "lessons"):
        if key not in data or not isinstance(data[key], list):
            data[key] = []

    return data


# ---------------------------------------------------------------------------
# Ogham write helpers
# ---------------------------------------------------------------------------

def store_in_ogham(ogham_bin: str, profile: str, tags: str, content: str) -> None:
    """Store a single memory in Ogham. Logs warning on failure, never raises."""
    result = subprocess.run(
        [ogham_bin, "store", "--profile", profile, "--tags", tags, content],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        warn(f"ogham store failed: {result.stderr.strip()[:120]}")


def write_to_ogham(ogham_bin: str, profile: str, extracted: dict[str, Any]) -> None:
    """Write all extracted memories to Ogham."""
    for item in extracted.get("decisions", []):
        decision = item.get("decision", "")
        rationale = item.get("rationale", "")
        content = f"decision: {decision} — rationale: {rationale}"
        store_in_ogham(ogham_bin, profile, "type:decision,source:recover", content)

    for item in extracted.get("patterns", []):
        pattern = item.get("pattern", "")
        when = item.get("when_to_apply", "")
        content = f"pattern: {pattern} — when: {when}"
        store_in_ogham(ogham_bin, profile, "type:pattern,source:recover", content)

    for item in extracted.get("gotchas", []):
        problem = item.get("problem", "")
        fix = item.get("fix_or_workaround", "")
        content = f"bug: {problem} — fix: {fix}"
        store_in_ogham(ogham_bin, profile, "type:gotcha,source:recover", content)

    for item in extracted.get("lessons", []):
        cat = item.get("category", "FLOW")
        title = item.get("title", "")
        lesson = item.get("lesson", "")
        content = f"lesson: {title} — {lesson}"
        tags = f"type:lesson,source:recover,category:{cat}"
        store_in_ogham(ogham_bin, profile, tags, content)


# ---------------------------------------------------------------------------
# Brain file write helpers
# ---------------------------------------------------------------------------

def truncate(text: str, max_len: int = 80) -> str:
    """Truncate text to max_len characters."""
    return text[:max_len] if len(text) > max_len else text


def append_to_brain(brain_dir: Path, filename: str, content: str) -> None:
    """Append content to a brain/ file, creating it if needed."""
    target = brain_dir / filename
    if not target.is_file():
        warn(f"Brain file {filename} not found — skipping append")
        return
    with target.open("a", encoding="utf-8") as f:
        f.write(content)


def get_next_memory_number(brain_dir: Path, category: str) -> int:
    """Read memories.md and find the highest NNN for the given category, return next."""
    memories_file = brain_dir / "memories.md"
    if not memories_file.is_file():
        return 1
    text = memories_file.read_text()
    pattern = rf"### M-{re.escape(category)}-(\d+):"
    matches = re.findall(pattern, text)
    if not matches:
        return 1
    return max(int(n) for n in matches) + 1


def write_to_brain(brain_dir: Path, extracted: dict[str, Any]) -> None:
    """Append extracted memories to brain/ MD files."""
    brain_dir.mkdir(parents=True, exist_ok=True)

    # key_decisions.md
    for item in extracted.get("decisions", []):
        decision = item.get("decision", "")
        rationale = item.get("rationale", "")
        date = item.get("date", "unknown")
        title = truncate(decision)
        block = (
            f"\n### {title}\n"
            f"- **Date**: {date}\n"
            f"- **Decision**: {decision}\n"
            f"- **Rationale**: {rationale}\n"
            f"- **Source**: Recovered from session history\n"
        )
        append_to_brain(brain_dir, "key_decisions.md", block)

    # patterns.md
    for item in extracted.get("patterns", []):
        pattern = item.get("pattern", "")
        when = item.get("when_to_apply", "")
        date = item.get("date", "unknown")
        title = truncate(pattern)
        block = (
            f"\n### {title}\n"
            f"- **Date**: {date}\n"
            f"- **Pattern**: {pattern}\n"
            f"- **When to apply**: {when}\n"
            f"- **Source**: Recovered from session history\n"
        )
        append_to_brain(brain_dir, "patterns.md", block)

    # gotchas.md
    for item in extracted.get("gotchas", []):
        problem = item.get("problem", "")
        fix = item.get("fix_or_workaround", "")
        date = item.get("date", "unknown")
        title = truncate(problem)
        block = (
            f"\n### {title}\n"
            f"- **Date**: {date}\n"
            f"- **Problem**: {problem}\n"
            f"- **Fix/Workaround**: {fix}\n"
            f"- **Source**: Recovered from session history\n"
        )
        append_to_brain(brain_dir, "gotchas.md", block)

    # memories.md — track per-category counters to avoid re-reading for each item
    category_counters: dict[str, int] = {}
    for item in extracted.get("lessons", []):
        cat = item.get("category", "FLOW").upper()
        title = item.get("title", "")
        context = item.get("context", "")
        lesson = item.get("lesson", "")
        scope = item.get("scope", "")
        date = item.get("date", "unknown")

        if cat not in category_counters:
            category_counters[cat] = get_next_memory_number(brain_dir, cat)
        nnn = category_counters[cat]
        category_counters[cat] += 1

        block = (
            f"\n### M-{cat}-{nnn:03d}: {title}\n"
            f"- **Date**: {date}\n"
            f"- **Context**: {context}\n"
            f"- **Lesson**: {lesson}\n"
            f"- **Scope**: {scope}\n"
            f"- **Status**: ACTIVE\n"
        )
        append_to_brain(brain_dir, "memories.md", block)


# ---------------------------------------------------------------------------
# Batch processing
# ---------------------------------------------------------------------------

def build_batch_prompt(sessions: list[dict[str, Any]], conn: sqlite3.Connection) -> str:
    """Build the full LLM prompt for a batch of sessions."""
    parts = [EXTRACTION_SYSTEM_PROMPT, "\n\n---\n\n"]

    for session in sessions:
        session_id = session["id"]
        title = session.get("title") or session_id
        ts_ms = session.get("time_created", 0)
        date_str = datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc).strftime("%Y-%m-%d")

        transcript = reconstruct_session(conn, session_id)
        if not transcript.strip():
            continue

        parts.append(f"=== SESSION: {title} ({date_str}) ===\n")
        parts.append(transcript)
        parts.append("\n=== END SESSION ===\n\n")

    return "".join(parts)


def process_batches(
    sessions: list[dict[str, Any]],
    conn: sqlite3.Connection,
    opencode_bin: str,
    ogham_bin: str,
    model: str,
    project_dir: Path,
    profile: str,
    batch_size: int,
    dry_run: bool,
    db_path: Path,
) -> dict[str, int]:
    """Process all sessions in batches. Returns totals dict."""
    totals = {"decisions": 0, "patterns": 0, "gotchas": 0, "lessons": 0}
    brain_dir = project_dir / ".ai" / "telamon" / "memory" / "brain"

    total_sessions = len(sessions)
    num_batches = (total_sessions + batch_size - 1) // batch_size

    for batch_idx in range(num_batches):
        start = batch_idx * batch_size
        end = min(start + batch_size, total_sessions)
        batch = sessions[start:end]

        log(f"Processing batch {batch_idx + 1}/{num_batches} (sessions {start + 1}-{end} of {total_sessions})...")

        if dry_run:
            log("  [dry-run] Would call LLM and write memories")
            continue

        prompt = build_batch_prompt(batch, conn)

        pre_call_ids = get_all_session_ids(db_path, str(project_dir))
        raw_response = call_llm(opencode_bin, model, str(project_dir), prompt)
        post_call_ids = get_all_session_ids(db_path, str(project_dir))
        new_session_ids = post_call_ids - pre_call_ids
        if new_session_ids:
            delete_sessions(db_path, new_session_ids)
        if raw_response is None:
            warn(f"  Batch {batch_idx + 1} LLM call failed — skipping")
            continue

        extracted = parse_llm_response(raw_response)
        if extracted is None:
            warn(f"  Batch {batch_idx + 1} JSON parse failed — skipping")
            continue

        n_dec = len(extracted.get("decisions", []))
        n_pat = len(extracted.get("patterns", []))
        n_got = len(extracted.get("gotchas", []))
        n_les = len(extracted.get("lessons", []))

        log(f"  → Extracted: {n_dec} decisions, {n_pat} patterns, {n_got} gotchas, {n_les} lessons")

        write_to_ogham(ogham_bin, profile, extracted)
        write_to_brain(brain_dir, extracted)

        log("  → Written to Ogham and brain/ files")

        totals["decisions"] += n_dec
        totals["patterns"] += n_pat
        totals["gotchas"] += n_got
        totals["lessons"] += n_les

    return totals


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract structured memories from past opencode session transcripts.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--project", required=True, metavar="PATH",
        help="Absolute path to the project directory (must have .ai/telamon/telamon.jsonc)",
    )
    parser.add_argument(
        "--model", required=True, metavar="MODEL",
        help="LLM model string (e.g. github-copilot/claude-sonnet-4)",
    )
    parser.add_argument(
        "--full", action="store_true",
        help="Full reset: export Ogham backup, clear profile, reset brain/ files, reprocess all sessions",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be processed without making changes",
    )
    parser.add_argument(
        "--batch-size", type=int, default=5, metavar="N",
        help="Number of sessions per LLM batch call (default: 5)",
    )
    parser.add_argument(
        "--db", type=Path, default=DEFAULT_DB, metavar="PATH",
        help=f"Path to opencode SQLite database (default: {DEFAULT_DB})",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    project_dir = Path(args.project).resolve()
    ini_path = project_dir / ".ai" / "telamon" / "telamon.jsonc"

    if not ini_path.is_file():
        log(f"ERROR: {ini_path} not found — is this a telamon project?")
        sys.exit(1)

    project_name = read_ini(ini_path, "project_name") or project_dir.name.lower()
    profile = project_name

    opencode_bin = find_opencode()
    ogham_bin = find_ogham()

    log(f"Project: {project_name} (profile: {profile})")
    log(f"Model: {args.model}")
    if args.dry_run:
        log("Mode: DRY RUN — no changes will be made")
    elif args.full:
        log("Mode: FULL RESET")

    # ── Step 1: Discover sessions ────────────────────────────────────────────
    conn = open_db(args.db)
    all_sessions = discover_sessions(conn, str(project_dir))

    if not all_sessions:
        log(f"No sessions found for project directory '{project_dir}' — nothing to do.")
        sys.exit(0)

    # ── Tracking file ────────────────────────────────────────────────────────
    track_path = tracking_path(project_dir, project_name)
    tracking = load_tracking(track_path)
    already_processed: set[str] = set(tracking.get("processed_sessions", []))

    if args.full:
        sessions_to_process = all_sessions
        already_processed = set()
    else:
        sessions_to_process = [s for s in all_sessions if s["id"] not in already_processed]

    n_total = len(all_sessions)
    n_new = len(sessions_to_process)
    n_done = n_total - n_new

    log(f"Found {n_total} sessions ({n_new} new, {n_done} already processed)")

    if args.dry_run:
        if sessions_to_process:
            sample = sessions_to_process[0]
            ts_ms = sample.get("time_created", 0)
            date_str = datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc).strftime("%Y-%m-%d")
            log(f"Sample session: '{sample.get('title')}' ({date_str})")
            log("Sample extraction prompt (first 500 chars):")
            prompt_preview = EXTRACTION_SYSTEM_PROMPT[:500] + "..."
            print(prompt_preview, file=sys.stderr)
        log("Dry run complete — no changes made.")
        return

    if not sessions_to_process:
        log("All sessions already processed — nothing to do.")
        return

    # ── Step 2: Full reset ───────────────────────────────────────────────────
    if args.full:
        log("Performing full reset ...")
        full_reset_ogham(profile, project_dir, ogham_bin)
        reset_brain_files(project_dir, project_name)
        tracking["processed_sessions"] = []

    # ── Steps 3-6: Process batches ───────────────────────────────────────────
    totals = process_batches(
        sessions=sessions_to_process,
        conn=conn,
        opencode_bin=opencode_bin,
        ogham_bin=ogham_bin,
        model=args.model,
        project_dir=project_dir,
        profile=profile,
        batch_size=args.batch_size,
        dry_run=args.dry_run,
        db_path=args.db,
    )

    # ── Step 7: Update tracking file ─────────────────────────────────────────
    processed_ids = [s["id"] for s in sessions_to_process]
    existing = set(tracking.get("processed_sessions", []))
    existing.update(processed_ids)
    tracking["processed_sessions"] = sorted(existing)
    save_tracking(track_path, tracking)

    num_batches = (n_new + args.batch_size - 1) // args.batch_size
    log(f"Done! Processed {n_new} sessions in {num_batches} batches.")
    log(
        f"  Total: {totals['decisions']} decisions, {totals['patterns']} patterns, "
        f"{totals['gotchas']} gotchas, {totals['lessons']} lessons"
    )
    log("  Tracking file updated.")


if __name__ == "__main__":
    main()

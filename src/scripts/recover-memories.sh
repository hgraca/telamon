#!/usr/bin/env bash
# recover-memories — Extract memories from past opencode session transcripts.
#
# Reads the opencode SQLite database, reconstructs session transcripts for the
# target project, sends them in batches to an LLM, and writes extracted
# decisions, patterns, gotchas, and lessons to the brain/ markdown files.
#
# Usage:
#   recover-memories [path]          # incremental — specific project (default: cwd)
#   recover-memories --all           # incremental — all initialized projects
#   recover-memories --full          # full reset — clear existing, reprocess all
#   recover-memories --dry-run       # preview without making changes
#   recover-memories --batch-size N  # sessions per LLM call (default: 5)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TOOLS_PATH="${TELAMON_ROOT}/src/tools"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# ── Constants ──────────────────────────────────────────────────────────────────
OPENCODE_DB="${HOME}/.local/share/opencode/opencode.db"
DEFAULT_BATCH_SIZE=5

# ── Parse arguments ────────────────────────────────────────────────────────────
PROJECT_PATH=""
ALL_PROJECTS=false
FULL_RESET=false
DRY_RUN=false
BATCH_SIZE="${DEFAULT_BATCH_SIZE}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)        ALL_PROJECTS=true; shift ;;
    --full)       FULL_RESET=true; shift ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --batch-size) BATCH_SIZE="$2"; shift 2 ;;
    --*)          error "Unknown flag: $1" ;;
    *)            PROJECT_PATH="$1"; shift ;;
  esac
done

# Resolve project path
if [[ -z "${PROJECT_PATH}" ]]; then
  PROJECT_PATH="$(pwd)"
fi
[[ "${PROJECT_PATH}" != /* ]] && PROJECT_PATH="$(cd "${PROJECT_PATH}" && pwd)"

# ── Validate prerequisites ─────────────────────────────────────────────────────
if [[ ! -f "${OPENCODE_DB}" ]]; then
  error "Opencode database not found at ${OPENCODE_DB}"
fi

if ! command -v python3 &>/dev/null; then
  error "python3 is required but not found"
fi

# ── Discover projects ──────────────────────────────────────────────────────────
declare -a PROJECTS=()

if [[ "${ALL_PROJECTS}" == "true" ]]; then
  # Find all initialized projects (those with .ai/telamon/memory directory)
  while IFS= read -r dir; do
    PROJECTS+=("$(dirname "$(dirname "$(dirname "${dir}")")")")
  done < <(python3 -c "
import sqlite3, json, os
conn = sqlite3.connect('${OPENCODE_DB}')
cur = conn.cursor()
cur.execute('SELECT DISTINCT worktree FROM project')
for row in cur.fetchall():
    path = row[0]
    if os.path.isdir(os.path.join(path, '.ai', 'telamon', 'memory')):
        print(path)
")
else
  if [[ ! -d "${PROJECT_PATH}/.ai/telamon/memory" ]]; then
    error "Not an initialized Telamon project: ${PROJECT_PATH} (missing .ai/telamon/memory)"
  fi
  PROJECTS+=("${PROJECT_PATH}")
fi

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
  warn "No initialized projects found"
  exit 0
fi

# ── Confirm --all ──────────────────────────────────────────────────────────────
if [[ "${ALL_PROJECTS}" == "true" && "${DRY_RUN}" == "false" ]]; then
  echo ""
  info "Will process ${#PROJECTS[@]} project(s):"
  for p in "${PROJECTS[@]}"; do
    echo "    • ${p}"
  done
  echo ""
  ask "Continue? [y/N]"
  read -r reply </dev/tty
  [[ "${reply,,}" == "y" ]] || { echo "Aborted."; exit 0; }
fi

# ── Process each project ──────────────────────────────────────────────────────
for PROJ in "${PROJECTS[@]}"; do
  header "Recovering memories: $(basename "${PROJ}")"

  BRAIN_DIR="${PROJ}/.ai/telamon/memory/brain"
  THINKING_DIR="${PROJ}/.ai/telamon/memory/thinking"
  TRACKER_FILE="${THINKING_DIR}/.recover-memories-$(basename "${PROJ}").json"

  # Resolve medium model
  MEDIUM_MODEL=""
  if [[ "${DRY_RUN}" == "false" ]]; then
    MEDIUM_MODEL="$(config.resolve_medium_model "${PROJ}")" || {
      warn "Could not resolve medium_model for ${PROJ} — skipping"
      continue
    }
  fi

  # Full reset: clear tracker
  if [[ "${FULL_RESET}" == "true" ]]; then
    rm -f "${TRACKER_FILE}"
    step "Full reset — will reprocess all sessions"
  fi

  # Load previously processed session IDs
  declare -a PROCESSED_IDS=()
  if [[ -f "${TRACKER_FILE}" ]]; then
    while IFS= read -r sid; do
      PROCESSED_IDS+=("${sid}")
    done < <(python3 -c "
import json, sys
with open('${TRACKER_FILE}') as f:
    data = json.load(f)
for sid in data.get('processed_sessions', []):
    print(sid)
")
  fi

  # Query sessions for this project
  SESSION_DATA="$(python3 - "${OPENCODE_DB}" "${PROJ}" "$(IFS=,; echo "${PROCESSED_IDS[*]:-}")" <<'PYEOF'
import sqlite3, json, sys

db_path = sys.argv[1]
project_path = sys.argv[2]
already_processed = set(filter(None, sys.argv[3].split(','))) if len(sys.argv) > 3 else set()

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Find project ID by worktree path
cur.execute("SELECT id FROM project WHERE worktree = ?", (project_path,))
row = cur.fetchone()
if not row:
    print(json.dumps({"error": "project_not_found", "sessions": []}))
    sys.exit(0)

project_id = row[0]

# Get all sessions for this project, ordered by creation time
cur.execute("""
    SELECT id, title, time_created
    FROM session
    WHERE project_id = ?
    ORDER BY time_created ASC
""", (project_id,))

sessions = []
for sid, title, time_created in cur.fetchall():
    if sid in already_processed:
        continue
    sessions.append({"id": sid, "title": title, "time_created": time_created})

print(json.dumps({"sessions": sessions}))
PYEOF
)"

  # Parse session list
  SESSION_COUNT="$(echo "${SESSION_DATA}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('sessions',[])))")"
  ERROR_CHECK="$(echo "${SESSION_DATA}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',''))")"

  if [[ "${ERROR_CHECK}" == "project_not_found" ]]; then
    warn "Project '${PROJ}' not found in opencode database — skipping"
    continue
  fi

  info "${SESSION_COUNT} new session(s) to process (batch size: ${BATCH_SIZE})"

  if [[ "${SESSION_COUNT}" -eq 0 ]]; then
    skip "No new sessions to process"
    unset PROCESSED_IDS
    continue
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    info "[dry-run] Would process ${SESSION_COUNT} sessions in $(( (SESSION_COUNT + BATCH_SIZE - 1) / BATCH_SIZE )) batch(es)"
    unset PROCESSED_IDS
    continue
  fi

  # Process sessions in batches
  BATCH_NUM=0
  TOTAL_BATCHES=$(( (SESSION_COUNT + BATCH_SIZE - 1) / BATCH_SIZE ))

  while [[ ${BATCH_NUM} -lt ${TOTAL_BATCHES} ]]; do
    OFFSET=$(( BATCH_NUM * BATCH_SIZE ))
    step "Batch $(( BATCH_NUM + 1 ))/${TOTAL_BATCHES} (sessions $((OFFSET + 1))–$(( OFFSET + BATCH_SIZE < SESSION_COUNT ? OFFSET + BATCH_SIZE : SESSION_COUNT )))"

    # Extract transcript text for this batch of sessions
    TRANSCRIPT="$(python3 - "${OPENCODE_DB}" "${SESSION_DATA}" "${OFFSET}" "${BATCH_SIZE}" <<'PYEOF'
import sqlite3, json, sys
from datetime import datetime

db_path = sys.argv[1]
session_data = json.loads(sys.argv[2])
offset = int(sys.argv[3])
batch_size = int(sys.argv[4])

sessions = session_data["sessions"][offset:offset + batch_size]
conn = sqlite3.connect(db_path)
cur = conn.cursor()

output_parts = []

for sess in sessions:
    sid = sess["id"]
    title = sess.get("title", "Untitled")
    ts = datetime.fromtimestamp(sess["time_created"] / 1000).strftime("%Y-%m-%d %H:%M")

    output_parts.append(f"\n{'='*60}\nSESSION: {title} ({ts})\n{'='*60}\n")

    # Get messages for this session, ordered by creation time
    cur.execute("""
        SELECT id, data FROM message
        WHERE session_id = ?
        ORDER BY time_created ASC
    """, (sid,))

    for msg_id, msg_data_raw in cur.fetchall():
        msg = json.loads(msg_data_raw)
        role = msg.get("role", "unknown")
        output_parts.append(f"\n[{role.upper()}]")

        # Get parts for this message
        cur.execute("""
            SELECT data FROM part
            WHERE message_id = ?
            ORDER BY time_created ASC
        """, (msg_id,))

        for (part_data_raw,) in cur.fetchall():
            part = json.loads(part_data_raw)
            ptype = part.get("type", "")

            if ptype == "text":
                text = part.get("text", "")
                # Truncate very long texts to avoid token blowout
                if len(text) > 3000:
                    text = text[:3000] + "\n[...truncated...]"
                output_parts.append(text)

# Combine and truncate total output to avoid exceeding model limits
full_text = "\n".join(output_parts)
# Cap at ~80K chars (~20K tokens) per batch
if len(full_text) > 80000:
    full_text = full_text[:80000] + "\n\n[...truncated due to length...]"

print(full_text)
PYEOF
)"

    # Send to LLM for extraction
    EXTRACTION="$(python3 - "${MEDIUM_MODEL}" "${TRANSCRIPT}" "${PROJ}" <<'PYEOF'
import subprocess, sys, json, os

model = sys.argv[1]
transcript = sys.argv[2]
project_path = sys.argv[3]
project_name = os.path.basename(project_path)

system_prompt = f"""You are a memory extraction agent for the "{project_name}" project.

Analyze the session transcript below and extract:
1. **Decisions** — architectural or product decisions made (ADRs or PDRs)
2. **Patterns** — coding patterns, conventions, or approaches established
3. **Gotchas** — traps, bugs, constraints, or things that don't work as expected
4. **Lessons** — general knowledge, tips, or workflow improvements

Output ONLY valid JSON with this structure:
{{
  "decisions": [
    {{"type": "architecture|product", "summary": "one-line summary", "detail": "explanation with context"}}
  ],
  "patterns": [
    {{"summary": "one-line summary", "detail": "explanation"}}
  ],
  "gotchas": [
    {{"summary": "one-line summary", "detail": "explanation including what went wrong and the fix"}}
  ],
  "lessons": [
    {{"category": "category-slug", "summary": "one-line summary", "detail": "explanation"}}
  ]
}}

Rules:
- Only extract genuinely useful, non-obvious knowledge.
- Skip trivial conversations, greetings, or routine tool usage.
- Skip anything already implied by standard frameworks or documentation.
- If nothing useful is found, return empty arrays.
- Keep summaries concise (< 80 chars). Keep details under 200 chars.
- For decisions, distinguish "architecture" (technical) from "product" (business/UX).
"""

user_prompt = f"Extract memories from these session transcripts:\n\n{transcript}"

# Use opencode CLI to call the LLM
try:
    result = subprocess.run(
        ["opencode", "run", "-m", model, "--no-tools", "-p", user_prompt, "-s", system_prompt],
        capture_output=True, text=True, timeout=120
    )
    output = result.stdout.strip()

    # Try to extract JSON from the output (may be wrapped in markdown code blocks)
    if "```json" in output:
        output = output.split("```json")[1].split("```")[0].strip()
    elif "```" in output:
        output = output.split("```")[1].split("```")[0].strip()

    # Validate JSON
    parsed = json.loads(output)
    print(json.dumps(parsed))
except subprocess.TimeoutExpired:
    print(json.dumps({"error": "timeout", "decisions": [], "patterns": [], "gotchas": [], "lessons": []}), file=sys.stderr)
    print(json.dumps({"decisions": [], "patterns": [], "gotchas": [], "lessons": []}))
except json.JSONDecodeError as e:
    print(json.dumps({"error": f"json_parse: {e}", "raw": output[:500]}), file=sys.stderr)
    print(json.dumps({"decisions": [], "patterns": [], "gotchas": [], "lessons": []}))
except Exception as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    print(json.dumps({"decisions": [], "patterns": [], "gotchas": [], "lessons": []}))
PYEOF
)"

    # Append extracted memories to brain/ files
    python3 - "${EXTRACTION}" "${BRAIN_DIR}" <<'PYEOF'
import json, sys, os
from datetime import datetime

extraction = json.loads(sys.argv[1])
brain_dir = sys.argv[2]
now = datetime.now().strftime("%Y-%m-%d")

def ensure_file(path, header=""):
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(header + "\n")

def append_to_file(path, content):
    with open(path, 'a') as f:
        f.write(content)

# Write decisions to ADRs.md or PDRs.md
for d in extraction.get("decisions", []):
    dtype = d.get("type", "architecture")
    target = "ADRs.md" if dtype == "architecture" else "PDRs.md"
    path = os.path.join(brain_dir, target)
    ensure_file(path, f"# {'Architecture' if dtype == 'architecture' else 'Product'} Decisions\n")
    entry = f"\n### {d['summary']}\n- **Date**: {now}\n- {d.get('detail', '')}\n"
    append_to_file(path, entry)

# Write patterns
for p in extraction.get("patterns", []):
    path = os.path.join(brain_dir, "patterns.md")
    ensure_file(path, "# Patterns\n")
    entry = f"\n### {p['summary']}\n- **Date**: {now}\n- {p.get('detail', '')}\n"
    append_to_file(path, entry)

# Write gotchas
for g in extraction.get("gotchas", []):
    path = os.path.join(brain_dir, "gotchas.md")
    ensure_file(path, "# Gotchas\n")
    entry = f"\n### {g['summary']}\n- **Date**: {now}\n- {g.get('detail', '')}\n"
    append_to_file(path, entry)

# Write lessons to memories.md
for l in extraction.get("lessons", []):
    path = os.path.join(brain_dir, "memories.md")
    ensure_file(path, "# Memories\n")
    cat = l.get("category", "general")
    entry = f"\n### [{cat}] {l['summary']}\n- **Date**: {now}\n- {l.get('detail', '')}\n"
    append_to_file(path, entry)

# Summary
total = (len(extraction.get("decisions", [])) +
         len(extraction.get("patterns", [])) +
         len(extraction.get("gotchas", [])) +
         len(extraction.get("lessons", [])))
print(total)
PYEOF

    # Track processed session IDs
    BATCH_SESSION_IDS="$(echo "${SESSION_DATA}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
offset = ${OFFSET}
batch_size = ${BATCH_SIZE}
sessions = data['sessions'][offset:offset + batch_size]
for s in sessions:
    print(s['id'])
")"

    # Update tracker file
    mkdir -p "${THINKING_DIR}"
    python3 - "${TRACKER_FILE}" "${BATCH_SESSION_IDS}" <<'PYEOF'
import json, sys, os

tracker_file = sys.argv[1]
new_ids = [line.strip() for line in sys.argv[2].strip().split('\n') if line.strip()]

existing = {"processed_sessions": []}
if os.path.exists(tracker_file):
    with open(tracker_file) as f:
        existing = json.load(f)

existing["processed_sessions"].extend(new_ids)

with open(tracker_file, 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
PYEOF

    BATCH_NUM=$(( BATCH_NUM + 1 ))
  done

  log "Done — processed ${SESSION_COUNT} sessions for $(basename "${PROJ}")"
  unset PROCESSED_IDS
done

echo ""
log "Memory recovery complete"

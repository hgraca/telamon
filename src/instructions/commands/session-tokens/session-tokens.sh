#!/usr/bin/env bash
# session-tokens.sh — sum input/output/reasoning/cache tokens for an opencode
# session, including all descendant subagent sessions.
#
# Usage: session-tokens.sh <session-id>

set -euo pipefail

DB_PATH="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"

if [[ ! -f "$DB_PATH" ]]; then
  echo "opencode database not found at $DB_PATH" >&2
  exit 1
fi

SESSION_ID="${1:-}"

# Resolution order when no arg is given:
#   1. $OPENCODE_SESSION_ID env var (set by session-id-export plugin)
#   2. Per-PID session file written by the same plugin
#   3. Most-recently-updated session in the DB (last-resort fallback)
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="${OPENCODE_SESSION_ID:-}"
fi

if [[ -z "$SESSION_ID" && -n "${OPENCODE_PID:-}" ]]; then
  SESSION_FILE="${TMPDIR:-/tmp}/opencode-session-${OPENCODE_PID}"
  if [[ -r "$SESSION_FILE" ]]; then
    SESSION_ID="$(cat "$SESSION_FILE")"
  fi
fi

if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="$(sqlite3 "$DB_PATH" "SELECT id FROM session ORDER BY time_updated DESC LIMIT 1;")"
  if [[ -z "$SESSION_ID" ]]; then
    echo "No sessions found in $DB_PATH" >&2
    exit 1
  fi
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

# Verify session exists.
if [[ -z "$(sqlite3 "$DB_PATH" "SELECT id FROM session WHERE id = '${SESSION_ID//\'/\'\'}' LIMIT 1;")" ]]; then
  echo "Session not found: $SESSION_ID" >&2
  exit 1
fi

# Recursively collect parent + all descendant session IDs.
mapfile -t SESSION_IDS < <(sqlite3 "$DB_PATH" <<SQL
WITH RECURSIVE descendants(id) AS (
  SELECT id FROM session WHERE id = '${SESSION_ID//\'/\'\'}'
  UNION ALL
  SELECT s.id FROM session s JOIN descendants d ON s.parent_id = d.id
)
SELECT id FROM descendants;
SQL
)

SESSION_COUNT=${#SESSION_IDS[@]}

# Build a quoted, comma-separated list for the IN clause.
IN_LIST=""
for sid in "${SESSION_IDS[@]}"; do
  esc="${sid//\'/\'\'}"
  IN_LIST+="'${esc}',"
done
IN_LIST="${IN_LIST%,}"

# Pull all message data blobs for these sessions, sum token fields via jq.
# Each blob has shape: { tokens: { input, output, reasoning, cache: {read, write} }, ... }
sqlite3 -separator $'\n' "$DB_PATH" \
  "SELECT data FROM message WHERE session_id IN ($IN_LIST);" \
| jq -s --arg root "$SESSION_ID" --argjson n "$SESSION_COUNT" '
    map(select(.tokens != null) | .tokens) as $t
    | {
        session: $root,
        sessions_included: $n,
        messages_with_tokens: ($t | length),
        input:     ($t | map(.input     // 0) | add // 0),
        output:    ($t | map(.output    // 0) | add // 0),
        reasoning: ($t | map(.reasoning // 0) | add // 0),
        cache_read:  ($t | map(.cache.read  // 0) | add // 0),
        cache_write: ($t | map(.cache.write // 0) | add // 0),
        total:     ($t | map(.total     // 0) | add // 0)
      }
  '

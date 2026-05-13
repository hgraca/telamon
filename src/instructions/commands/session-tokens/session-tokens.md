---
description: Report input/output/reasoning/cache token totals for an opencode session, including all subagent sessions
agent: telamon/telamon
---

Run `.opencode/commands/telamon/session-tokens/session-tokens.sh $1` and present resulting JSON to user.

If no argument provided, script auto-resolves current session in this order:

1. `$OPENCODE_SESSION_ID` env var (set by `session-id-export` plugin).
2. Per-PID file at `${TMPDIR:-/tmp}/opencode-session-${OPENCODE_PID}` (also written by plugin).
3. Most-recently-updated session in database (last-resort fallback).

Script:

- Recursively walks `session.parent_id` to include target session and every descendant subagent session.
- Sums `tokens.{input, output, reasoning, cache.read, cache.write, total}` across all messages in those sessions.
- Outputs single JSON object with totals.
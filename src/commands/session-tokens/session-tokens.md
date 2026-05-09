---
description: Report input/output/reasoning/cache token totals for an opencode session, including all subagent sessions
agent: telamon/telamon
---

Run `.opencode/commands/telamon/session-tokens/session-tokens.sh $1` and present the resulting JSON to the user.

If no argument is provided, the script auto-resolves the current session in this order:

1. `$OPENCODE_SESSION_ID` env var (set by the `session-id-export` plugin).
2. Per-PID file at `${TMPDIR:-/tmp}/opencode-session-${OPENCODE_PID}` (also written by the plugin).
3. Most-recently-updated session in the database (last-resort fallback).

The script:

- Recursively walks `session.parent_id` to include the target session and every descendant subagent session.
- Sums `tokens.{input, output, reasoning, cache.read, cache.write, total}` across all messages in those sessions.
- Outputs a single JSON object with the totals.

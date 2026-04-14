## cass — Agent Session History Search

cass indexes past agent session conversations and makes them searchable across
all coding agents (opencode, Claude Code, Codex, Cursor, Aider, and more).

**Full usage guide**: load the `cass` skill — it covers robot mode, token
budgets, health checks, time filters, and structured error handling.

### Critical: always use `--robot` flag

Never run bare `cass search` — it launches an interactive TUI that blocks the
agent session. Always use `--robot` or `--json` for machine-readable output.

### Quick reference:

```bash
# Pre-flight check
cass health --json || cass index --full

# Search (scoped to this project)
cass search "auth error" --robot --workspace "$(pwd)" --limit 5

# Minimal payload (low token cost)
cass search "auth error" --robot --fields minimal --limit 5

# Drill into a result
cass expand /path/to/session.jsonl -n 42 -C 5 --json
```

### Retrieve:
- Past session conversations: `cass search "<topic>" --robot --workspace "$(pwd)"`
- Self-documenting API: `cass robot-docs guide`

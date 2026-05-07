---
layout: page
title: Status Marker Enforcer
description: OpenCode plugin that nudges agents to emit a terminal status marker when they stall.
nav_section: docs
---

Status Marker Enforcer — Detect stalled agent turns and nudge for a status signal.

An OpenCode plugin that fires on `session.idle` events. If the last assistant message lacks one of the four canonical status markers, the plugin sends a synthetic, hidden prompt asking the agent to emit `FINISHED!`, `BLOCKED:`, `NEEDS_INPUT:`, or `PARTIAL:`.

## Why

Agents sometimes end a turn with narration ("Now I will write the file…") instead of a terminal status marker. Downstream automation (orchestrator routing, retrospectives, exception handling) depends on the marker. Without it, work hangs silently.

## Behavior

- Fires on `session.idle` after the assistant's turn ends.
- Detects markers via regex sourced from `agent-communication/SKILL.md` lines 19–24 (single source of truth — drift is enforced by a parity test).
- Sends a synthetic, hidden nudge prompt (`metadata.hidden = true`) tagged `[Telamon-StatusEnforcer]` so it does not pollute the visible transcript.
- The nudge prompt lists all four markers and explicitly surfaces `PARTIAL:` and `NEEDS_INPUT:` as escape valves — preventing a default-to-`FINISHED!` failure mode.

## Loop prevention

Three layers, all worktree-scoped:

| Layer                  | Mechanism                                                                                        | TTL    |
|------------------------|--------------------------------------------------------------------------------------------------|--------|
| Lock file              | `.ai/telamon/memory/thinking/.agent-communication-lock-<slug>` skips re-entry within window      | 5 min  |
| Last-message tag check | Skips when the previous user message was already a `[Telamon-StatusEnforcer]` nudge              | n/a    |
| Attempt counter        | `.ai/telamon/memory/thinking/.agent-communication-counter-<slug>.json` caps attempts per session | 24h GC |

When the per-session attempt count hits `max_attempts` (default `2`), the plugin writes a stderr line and stops nudging that session:

```
[agent-communication] Session <id> exceeded max nudge attempts (<N>) — stopping. Human review needed.
```

## Coordination with Session Capture

This plugin coexists with [Session Capture](remember-session). On a stalled idle, Status Marker Enforcer writes a stall-flag file (`.ai/telamon/memory/thinking/.agent-communication-stall-<slug>.json`, 6-min TTL). Session Capture reads that flag and skips its capture pass while the flag is fresh and `attempt < max_attempts`. Once the agent emits a marker — or the attempt ceiling is reached — the flag clears and Session Capture proceeds normally.

## Configuration

In `.ai/telamon/telamon.jsonc`:

```jsonc
"agent_communication": {
  "enabled": true,
  "max_attempts": 2,
  "exempt_agents": ["repomix-agent", "qmd"]
}
```

| Key             | Default                    | Effect                                                           |
|-----------------|----------------------------|------------------------------------------------------------------|
| `enabled`       | `true`                     | Disable to short-circuit the handler before any side effects     |
| `max_attempts`  | `2`                        | Per-session ceiling; hitting it logs to stderr and stops nudging |
| `exempt_agents` | `["repomix-agent", "qmd"]` | Agent names exempted from nudging (no SDK calls made)            |

## Opt out

To disable globally, set `enabled: false` in the config block above.

To exempt a specific agent, add its name to `exempt_agents`.

**Type:** Built-in OpenCode plugin (`src/plugins/agent-communication.js`)

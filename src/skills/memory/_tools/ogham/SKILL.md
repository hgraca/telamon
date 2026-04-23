---
name: telamon.ogham
description: "Ogham semantic agent memory -- profile switching, storing, and searching. Use when storing decisions, patterns, bugs, lessons, or checkpoints in Ogham, searching past knowledge, or switching project profiles. Triggers: 'ogham store', 'ogham search', 'switch profile', 'remember this'."
allowed-tools: ogham_*
---

# Ogham -- Semantic Agent Memory

Persistent vector memory for decisions, patterns, bugs, lessons, and checkpoints. Backed by Postgres + pgvector with Ollama embeddings.

## When to Apply

- Switching Ogham profile at session start or when changing projects
- Storing decisions, bugs, patterns, rules, lessons, or checkpoints
- Searching past knowledge by meaning
- Recalling checkpoints after context compaction

## 1. Profile Resolution

Resolve the profile name once per session and use it on every ogham call.

**Resolution order** (first match wins):
1. Read `.ai/telamon/telamon.ini` — if `project_name` key exists, use its value.
2. Otherwise, use the lowercase basename of the project root directory (e.g., `/home/user/dev/k8s-gete` → `k8s-gete`).

Cache the resolved profile for the rest of the session.

**IMPORTANT — always pass `--profile`**: Every `ogham store` and `ogham search` call MUST include `--profile <resolved-profile>`. This prevents cross-project contamination when multiple sessions run concurrently. Never rely on `ogham use` alone — it sets global state that other sessions can overwrite.

You MAY still run `ogham use <profile>` at session start for convenience (e.g., so `ogham list` works interactively), but it is NOT a substitute for `--profile` on store/search calls.

## 2. Searching

Search by meaning (semantic + keyword hybrid):

```
ogham search --profile <profile> "<keywords or question>"
```

Common searches:
- Session start: `ogham search --profile <profile> "<current task or recent topic>"`
- After compaction: `ogham search --profile <profile> "checkpoint"`
- Past decisions: `ogham search --profile <profile> "decision <topic>"`

## 3. Storing

Store knowledge the moment it arises. One fact per call -- do not bundle.

| What happened                        | Command                                                                         |
|--------------------------------------|---------------------------------------------------------------------------------|
| Architectural or product decision    | `ogham store --profile <profile> "decision: X over Y because Z"`                |
| Human stakeholder answers a question | `ogham store --profile <profile> "decision: <Q> -> <A>"`                        |
| New rule given by stakeholder        | `ogham store --profile <profile> "rule: <rule>"`                                |
| Bug fixed (non-trivial)              | `ogham store --profile <profile> "bug: <desc and fix>"`                         |
| Pattern established                  | `ogham store --profile <profile> "pattern: <desc>"`                             |
| Lesson learned                       | `ogham store --profile <profile> "lesson: <one-line summary>"`                  |
| Checkpoint before compaction         | `ogham store --profile <profile> "checkpoint: <task> -- done: <X> -- next: <Y>"` |

## 4. What NOT to Store

- Secrets, API keys, passwords
- Raw command output or logs
- Trivial edits or routine operations
- Information already captured in brain/ notes (avoid duplication)

See the `telamon.memory_management` skill, section 4 (Never write) for the full list.

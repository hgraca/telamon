---
name: telamon.memory-management
description: "Manages the project's memories.md file for capturing, organizing, and applying lessons learned across sessions. Use when recording lessons, pruning stale entries, or consulting memory before starting new work."
---

# Skill: Memory Management

Structured process for maintaining the project's institutional memory across agent sessions. Ensures lessons learned are captured, categorized, retrievable, and pruned when stale.

## When to Apply

- After completing a planning or implementation stage (capture lessons)
- Before starting a new planning or implementation stage (consult lessons)
- When the PO identifies a reusable pattern or anti-pattern during work
- When memories.md grows beyond 100 entries (prune)

## File Location

`<project-root>/.ai/telamon/memory/brain/memories.md`

This file is loaded automatically during the bootstrap sequence (via `.ai/telamon/bootstrap/`), so all agents see its contents at session start.

## memories.md Structure

The file is organized into categories. Each entry has a consistent format within its category.

### Template

```markdown
# Memory

Institutional knowledge captured from past agent sessions. Read before starting new work. Entries are ordered newest-first within each category.

## Architecture Decisions

Lessons about project structure, layer boundaries, and dependency rules.

### M-ARCH-NNN: <title>
- **Date**: YYYY-MM-DD
- **Context**: What triggered this lesson.
- **Lesson**: The reusable takeaway.
- **Scope**: Where this applies (component, layer, or project-wide).
- **Status**: ACTIVE | SUPERSEDED by M-ARCH-XXX

## Testing Patterns

Lessons about test structure, test tooling, and testing strategies.

### M-TEST-NNN: <title>
- **Date**: YYYY-MM-DD
- **Context**: What triggered this lesson.
- **Lesson**: The reusable takeaway.
- **Scope**: Where this applies.
- **Status**: ACTIVE | SUPERSEDED by M-TEST-XXX

## Domain Knowledge

Business rules, domain semantics, and product decisions clarified during work.

### M-DOMAIN-NNN: <title>
- **Date**: YYYY-MM-DD
- **Context**: What triggered this lesson.
- **Lesson**: The reusable takeaway.
- **Scope**: Where this applies.
- **Status**: ACTIVE | SUPERSEDED by M-DOMAIN-XXX

## Anti-Patterns

Approaches that failed or caused problems — avoid repeating them.

### M-ANTI-NNN: <title>
- **Date**: YYYY-MM-DD
- **Context**: What went wrong.
- **Lesson**: What to do instead.
- **Scope**: Where this applies.
- **Status**: ACTIVE | SUPERSEDED by M-ANTI-XXX

## Workflow Lessons

Lessons about the agent workflow itself — delegation, communication, tooling.

### M-FLOW-NNN: <title>
- **Date**: YYYY-MM-DD
- **Context**: What triggered this lesson.
- **Lesson**: The reusable takeaway.
- **Scope**: Where this applies.
- **Status**: ACTIVE | SUPERSEDED by M-FLOW-XXX
```

## Entry Rules

- **One lesson per entry** — do not combine multiple takeaways into one entry.
- **Specific, not generic** — "Always include `--no-interaction` when running Artisan commands" is good. "Be careful with CLI commands" is too vague.
- **Include context** — future agents need to understand *why* this lesson exists.
- **Scope it** — a lesson about the Invoice component should say so, not imply it applies everywhere.
- **Number sequentially** — use the next available number within each category prefix.

## Capturing Lessons

The PO is responsible for writing entries. Capture lessons:

1. **Immediately** — after each task or iteration, not deferred to end of session.
2. **From all sources** — Q&A with stakeholders, Architect feedback, Critic findings, Reviewer findings, Developer observations, Tester bug reports.
3. **With attribution** — reference the issue folder or task that triggered it.

## Consulting Lessons

Before starting new work:

1. Read the full memories.md file (it is loaded during bootstrap).
2. Identify entries relevant to the current task's scope (component, layer, pattern).
3. Include relevant entries in delegation context when delegating to other agents.

## Pruning Rules

When memories.md grows beyond 100 entries or when architecture significantly changes:

1. Mark entries as `SUPERSEDED by M-XXX-NNN` when a newer entry replaces them.
2. Do not delete superseded entries immediately — keep them for one more session for traceability.
3. After one session, superseded entries may be removed.
4. Entries more than 6 months old should be reviewed for continued relevance.
5. Only the PO or human stakeholder may remove entries.

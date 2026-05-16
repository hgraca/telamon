---
name: telamon.gather-context
description: "Gather session context for orchestrator at session start. Use when scout agent is activated to prime context about a topic or project area."
---

# Gather Context

Use at session start to collect targeted context for the orchestrator before work begins.

## When to Apply

- Orchestrator delegates context-gathering for a topic or set of keywords.
- Session starts and orchestrator needs primed context before planning or delegating.

## Procedure

### 1. Identify keywords

Extract topic keywords from orchestrator's delegation prompt. If none provided, use project name and current task area.

### 2. Gather memory vault context

Call `gather-context` tool with extracted keywords:

```
gather-context({ keywords: ["<keyword1>", "<keyword2>"], format: "markdown", max_results: 5 })
```

Repeat with different keyword sets if first call returns sparse results.

### 3. Gather codebase context (if topic is code-related)

Use `codebase-index` to find relevant code locations:
- Search by meaning for each keyword
- Return file paths, symbol names, and brief descriptions

### 4. Gather directory structure (if topic is structural)

Use `glob` to list relevant directories and files matching the topic area.

### 5. Compile context report

Produce structured Markdown report with sections:

```markdown
# Context Report: <topic>

## Memory Vault
<findings from gather-context tool — decisions, patterns, lessons>

## Codebase Locations
<relevant files and symbols — omit if not code-related>

## Directory Structure
<relevant paths — omit if not structural>

## Summary
<2-4 sentences: what is known, what is missing, recommended starting points>
```

### 6. Signal completion

Signal `FINISHED` per `telamon.agent-communication` skill. Attach context report path or inline content.

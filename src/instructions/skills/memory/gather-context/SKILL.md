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

Extract topic keywords from orchestrator's delegation prompt. If none provided, ask for them.

### 2. Gather memories

Call the tool `search-memories` with the given keywords

### 3. Gather a git status report

Call the `git-report` tool

### 4. Gather codebase relationships knowledge (if topic is code-related)

Use the `graphify` skill to understand what are the most relevant folders/modules/nodes related to the given keywords

### 5. Gather codebase patterns and architecture context (if topic is code-related)

Use `codebase-index` MCP, specially `codebase_search`,  to understand the given keywords concepts within
the context of the codebase, codebase relationships, patterns, architecture, and find relevant code locations:
- Search by meaning for each keyword
- Return file paths, symbol names, and brief descriptions

### 6. Gather directory structure (if topic is code-related or structural)

Use the `tree` tool to generate tree views of the most relevant base folders.
Be careful to not duplicate tree structures by giving it a base folder path and a subfolder of that. 
In case of overlap, provide only the parent folder.

### 7. Compile context report

Produce structured Markdown report with sections:

```markdown
# Context Report

**Keywords**: <keyword-list>

## Memories

<!-- output body of `search-memories` tool -->

## Git status

<!-- output of `git-report` tool -->

## Graphify insights

<!-- report of the `graphify` insights — omit if not code-related -->

## Codebase-index insights

<!-- insights of the `codebase-index` — omit if not code-related -->

## Directory Structure

<!-- output of  the `tree` tool — omit if neither code-related nor structural -->

## Summary
<!-- 2-4 sentences: what is known, what is missing, recommended follow-up research -->
```

and:
- use the `caveman` skill on it to reduce the tokes cost

### 8. Store report to file

Write the compiled report to a file in `.ai/telamon/memory/thinking/` with the naming convention:

```
YYYYMMDDHHMMSS-<keyword-list>.md
```

Where:
- `YYYYMMDDHHMMSS` is the current UTC timestamp
- `<keyword-list>` is the keyword list joined by hyphens (e.g. `auth-jwt-login`)

Example: `20260518143000-auth-jwt-login.md`

### 9. Signal completion

Signal `FINISHED` per `telamon.agent-communication` skill.
Include in the signal:
- The **absolute path** of the report file written to `thinking/`.
- A brief summary (3–5 bullets) of the key findings.

The orchestrator will read the full report from disk and display it to the user.
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

### 0. Check cache (do this first — skip all other steps on hit)

Determine the keywords for this session (same list you will use in Step 1).
Call the `gather-context-cache` tool:

    gather-context-cache({ subcommand: "get", keywords: <keyword-list> })

- If the result is **non-empty**: return it immediately and signal `FINISHED` — do not execute Steps 1–7b.
- If the result is **empty** (cache miss or expired): continue to Step 1.

> **Important**: record the exact keyword list used here. You MUST use the identical list in Step 7b.

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

### 7b. Store report in cache

Call the `gather-context-cache` tool with the **same keyword list** used in Step 0:

    gather-context-cache({ subcommand: "store", keywords: <same-keyword-list-as-step-0>, content: <compiled-report> })

The tool writes the file and runs `format-md` automatically. Then continue to Step 8.

### 8. Signal completion

Signal `FINISHED` per `telamon.agent-communication` skill.
Include in the signal:
- The **absolute path** of the cached report file (returned by `gather-context-cache` in Step 7b, or the path of the existing cache file on a cache hit).
- A brief summary (3–5 bullets) of the key findings.

The orchestrator will read the full report from disk and display it to the user.

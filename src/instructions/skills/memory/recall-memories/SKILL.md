---
name: telamon.recall_memories
description: "Recall context at session start. Read brain/ notes, update vault index, initialize knowledge tools. Use at beginning of every session."
---

# Recall Memories

Use when you need a full brain/ notes read without a specific topic — e.g. switching projects, or when `gather-context` tool is insufficient for the current request.

For non-trivial project requests, prefer calling the `gather-context` tool with topic keywords instead — it gathers memory vault notes, codebase graph context, and directory trees in one targeted step.

## 1. Recall past context

Read brain/ notes directly -- see `telamon.memory_management` skill (Retrieval Rules, R2) for list and when to read each file.

## 2. Update memories

Use `telamon.qmd` skill to initialize and query non-bootstrap memories.

## 3. Self-initialize (check each time, build if missing)

**Graphify knowledge graph:** Use `telamon.graphify` skill to initialize graphify context.

**Semantic codebase index:**
- Check: does `.opencode/codebase-index/` exist?
- If NO: call `index_codebase` tool -- one-time build
- If YES: index is ready

## 4. Retrieval priority

When you need information, use right tool for question type:

| Question type                            | Tool                                                                      |
|------------------------------------------|---------------------------------------------------------------------------|
| Lessons learned (categorized)            | QMD search (`brain/memories.md`)                                          |
| Product decisions + stakeholder answers  | Read `brain/PDRs.md` directly                                             |
| Architectural/technical decisions        | Read `brain/ADRs.md` directly                                             |
| Codebase patterns                        | Read `brain/patterns.md` directly                                         |
| Known traps and constraints              | Read `brain/gotchas.md` directly                                          |
| Vault semantic search ("did we ever...") | Use `telamon.qmd` skill                                                   |
| Architecture, relationships, god nodes   | Use `telamon.graphify` skill                                              |
| Code by meaning ("find auth logic")      | codebase-index (ask naturally)                                            |
| Specs, ADRs, requirements                | QMD search (follow `telamon.memory_management` skill for retrieval rules) |

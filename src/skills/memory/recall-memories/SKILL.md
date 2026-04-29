---
name: telamon.recall_memories
description: "Recall context at session start. Read brain/ notes, update vault index, initialize knowledge tools. Use at the beginning of every session."
---

# Recall Memories

Run at the beginning of every session, regardless of workflow. Even standalone tasks must start here.

## 1. Recall past context

Read brain/ notes directly — see the `telamon.memory_management` skill (Retrieval Rules, R2) for the list and when to read each file.

## 2. Update vault index

Use the `telamon.qmd` skill to initialize and query the vault index.

## 3. Self-initialize (check each time, build if missing)

**Graphify knowledge graph:** Use the `telamon.graphify` skill to initialize graphify context.

**Semantic codebase index:**
- Check: does `.opencode/codebase-index/` exist?
- If NO: call `index_codebase` tool — one-time build
- If YES: index is ready

## 4. Retrieval priority

When you need information, use the right tool for the question type:

| Question type                                      | Tool                                                                                 |
|----------------------------------------------------|--------------------------------------------------------------------------------------|
| Lessons learned (categorized)                      | QMD search (`brain/memories.md`)                                                     |
| Product decisions + stakeholder answers         | Read `brain/PDRs.md` directly                                                        |
| Architectural/technical decisions               | Read `brain/ADRs.md` directly                                                        |
| Codebase patterns                                  | Read `brain/patterns.md` directly                                                    |
| Known traps and constraints                        | Read `brain/gotchas.md` directly                                                     |
| Vault semantic search ("did we ever...")           | Use the `telamon.qmd` skill                                                          |
| Architecture, relationships, god nodes             | Use the `telamon.graphify` skill                                                     |
| Code by meaning ("find auth logic")                | codebase-index (ask naturally)                                                       |
| Specs, ADRs, requirements                          | QMD search (follow `telamon.memory_management` skill for retrieval rules)            |

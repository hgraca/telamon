---
name: telamon.recall_memories
description: "Recall context at session start. Switch Ogham profile, search past work, read brain/ notes, update vault index, initialize knowledge tools. Use at the beginning of every session."
---

# Recall Memories

Run at the beginning of every session, regardless of workflow. Even standalone tasks must start here.

## 1. Switch memory profile

Use the `telamon.ogham` skill to switch to the project profile.

## 2. Recall past context

Use the `telamon.ogham` skill to search for relevant prior work.

Read brain/ notes directly — see the `telamon.memory_management` skill (Retrieval Rules, R2) for the list and when to read each file.

## 3. Update vault index

Use the `telamon.qmd` skill to initialize and query the vault index.

## 4. Self-initialize (check each time, build if missing)

**Graphify knowledge graph:** Use the `telamon.graphify` skill to initialize graphify context.

**Semantic codebase index:**
- Check: does `.opencode/codebase-index/` exist?
- If NO: call `index_codebase` tool — one-time build
- If YES: index is ready

## 5. Retrieval priority

When you need information, use the right tool for the question type:

| Question type                                      | Tool                                                                                 |
|----------------------------------------------------|--------------------------------------------------------------------------------------|
| Lessons learned (categorized)                      | Search Ogham or QMD (`brain/memories.md`)                                            |
| Architectural decisions + stakeholder answers      | Read `brain/key_decisions.md` directly                                               |
| Codebase patterns                                  | Read `brain/patterns.md` directly                                                    |
| Known traps and constraints                        | Read `brain/gotchas.md` directly                                                     |
| Vault semantic search ("did we ever...")           | Use the `telamon.qmd` skill                                                          |
| Architecture, relationships, god nodes             | Use the `telamon.graphify` skill                                                     |
| Relational/temporal queries ("what depends on X?") | Graphiti MCP (only when `telamon-graphiti` container is running)                     |
| Code by meaning ("find auth logic")                | codebase-index (ask naturally)                                                       |
| Past decisions/bugs this project                   | Use the `telamon.ogham` skill                                                        |
| Specs, ADRs, requirements                          | Obsidian vault search (follow `telamon.memory_management` skill for retrieval rules) |

## Switching projects

Use the `telamon.ogham` skill to switch profiles, then re-run steps 2-4 for the new project context.

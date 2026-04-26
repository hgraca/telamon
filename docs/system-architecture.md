---
layout: page
title: System Architecture
description: How Telamon's tools connect and what each provides at each stage of a session.
nav_section: docs
---

Telamon runs entirely on the developer's machine. An MCP layer connects the coding agent to local services (Postgres, Ollama, Obsidian) and external integrations (GitHub, browser DevTools). OpenCode plugins inject context at session start, and host CLI tools handle indexing, search, and compression.

## System flow

```
+----------------------------------------------------------------------+
|                         Developer Machine                             |
|                                                                       |
|  +-----------+    +--------------------------------------------------+|
|  | opencode  |<-->|                   MCP Layer                      ||
|  |  (agent)  |    |  +-------+ +----------+ +---------+ +---------+ ||
|  +-----------+    |  | ogham | | codebase-| |obsidian | |graphify | ||
|       |           |  |  MCP  | |   index  | |   MCP   | |   MCP   | ||
|       |           |  +---+---+ +-----+----+ +----+----+ +----+----+ ||
|       |           |  +-------+ +----------+ +---------+ +---------+ ||
|       |           |  |  qmd  | |  github  | |chromdev| |playwrit | ||
|       |           |  |  MCP  | |   MCP    | |  MCP   | |  MCP    | ||
|       |           |  +---+---+ +-----+----+ +----+----+ +----+----+ ||
|       |           |  +-------+ +----------+ +---------+              ||
|       |           |  |  git  | | ast-grep | |context7 |              ||
|       |           |  |  MCP  | |   MCP    | |   MCP   |              ||
|       |           |  +---+---+ +-----+----+ +----+----+              ||
|       |           |  +-------+                                        ||
|       |           |  |repomix|                                        ||
|       |           |  |  MCP  |                                        ||
|       |           |  +---+---+                                        ||
|       |           +------+------------+----------+-------------------+|
|       |                  |            |          |                    |
|       |          +-------v------+  +--v-----+  +--v--------+         |
|       |          |  Postgres +  |  | Ollama |  | Obsidian  |         |
|       |          |  pgvector    |  | :17434 |  |   vault   |         |
|       |          +--------------+  +--------+  +-----------+         |
|       |                                                              |
|  +----v---------------------------------------------------------+    |
|  |                    Host CLI Tools                             |    |
|  |  graphify  .  rtk  .  ogham  .  qmd                      |    |
|  +---------------------------------------------------------------+   |
|                                                                       |
|  +---------------------------------------------------------------+    |
|  |              OpenCode Plugins (always-on)                     |    |
|  |  session-capture . graphify . rtk-dedupe . diff-context       |    |
|  +---------------------------------------------------------------+    |
|                                                                       |
|  +---------------------------------------------------------------+    |
|  |              Agent Roles (src/agents/)                        |    |
|  |  telamon . architect . developer . tester . reviewer          |    |
|  |  critic . po . security . ui-designer . ux-designer           |    |
|  +---------------------------------------------------------------+    |
|                                                                       |
|  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    |
|  │           Optional Services (profile-gated)                   │    |
|  │  Langfuse (postgres + redis + clickhouse + web)               │    |
|  │  Graphiti (neo4j + graphiti API)                               │    |
|  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    |
+----------------------------------------------------------------------+
```

---

## What each tool provides at each stage

| Stage | Tool | Role |
|---|---|---|
| **Session start** | Ogham | Recalls past decisions, bugs, and patterns for this project |
| **Session start** | Obsidian `brain/` | Loads goals, decisions, patterns, and known gotchas |
| **Session start** | QMD | Semantic vault search — surfaces related context before diving in |
| **Session start** | Graphify plugin | Injects god nodes, communities, and surprising connections |
| **Session start** | Diff-context plugin | Injects git change summary since last session |
| **Understanding code** | Graphify MCP | Structural map: layers, god nodes, module relationships |
| **Finding code** | Codebase Index | Semantic search: *"where is the auth logic?"* |
| **Reading many files** | Repomix | Packs directory into compressed context (~70% token reduction) |
| **Finding code** | ast-grep | Structural search: find code by AST pattern |
| **Finding vault notes** | QMD | Semantic vault search: *"did we ever deal with X?"* |
| **Looking up docs** | Context7 | Queries library/framework documentation |
| **Browser debugging** | Chrome DevTools | Inspects DOM, console, network, performance |
| **Browser testing** | Playwright | Automates browser interactions and assertions |
| **GitHub integration** | GitHub MCP | Manages issues, PRs, code search, reviews |
| **Writing code** | RTK | Compresses bash output to save tokens |
| **Long sessions** | Caveman | Reduces response verbosity ~75% on demand |
| **After significant work** | Ogham + Obsidian | Stores new decisions, patterns, bug fixes |
| **Evaluating agent behavior** | promptfoo | Automated quality checks: routing, plan structure, code review |
| **After each agent turn** | Session Capture | Auto-promotes learnings every 30 min (throttled) |
| **End of session** | Ogham + Obsidian | Saves session summary; archives completed work notes |
| **Observability** | Langfuse (optional) | Tracks token usage, latency, cost across sessions |
| **Temporal knowledge** | Graphiti (optional) | Stores entities and relationships with temporal metadata |

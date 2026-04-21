---
layout: page
title: System Architecture
description: How Telamon's tools connect and what each provides at each stage of a session.
nav_section: docs
---

How Telamon's tools connect and what each provides at each stage of a session.

---

## System Flow

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
|       |          +-------v------+  +--v----+  +--v--------+          |
|       |          |  Postgres +  |  |Ollama |  | Obsidian  |          |
|       |          |  pgvector    |  |:11434 |  |   vault   |          |
|       |          +--------------+  +-------+  +-----------+          |
|       |                                                              |
|  +----v---------------------------------------------------------+    |
|  |                    Host CLI Tools                             |    |
|  |  graphify  .  cass  .  rtk  .  ogham  .  qmd                 |    |
|  +---------------------------------------------------------------+   |
|                                                                       |
|  +---------------------------------------------------------------+    |
|  |              OpenCode Plugins (always-on)                     |    |
|  |  session-capture . graphify . rtk-dedupe . diff-context . scheduler |  |
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
| **Session start** | Graphify plugin | Injects god nodes, communities, and surprising connections into the first tool call |
| **Session start** | Diff-context plugin | Injects git change summary (commits + diffstat) since last session into the first bash call |
| **Understanding code** | Graphify MCP | Structural map: layers, god nodes, module relationships |
| **Finding code** | Codebase Index | Semantic search: *"where is the auth logic?"* |
| **Reading many files** | Repomix | Packs directory into compressed context (~70% token reduction) |
| **Finding code** | ast-grep | Structural search: find code by AST pattern |
| **Finding vault notes** | QMD | Semantic vault search: *"did we ever deal with X?"* |
| **Recovering past context** | cass | Searches previous agent session transcripts |
| **Looking up docs** | Context7 | Queries up-to-date library/framework documentation |
| **Browser debugging** | Chrome DevTools | Inspects DOM, console, network, performance |
| **Browser testing** | Playwright | Automates browser interactions and assertions |
| **GitHub integration** | GitHub MCP | Manages issues, PRs, code search, reviews |
| **Writing code** | RTK | Compresses bash output to save tokens |
| **Long sessions** | Caveman | Reduces response verbosity ~75% on demand |
| **After significant work** | Ogham | Stores new decisions, patterns, bug fixes |
| **After significant work** | Obsidian | Promotes learnings to `brain/` notes |
| **Evaluating agent behavior** | promptfoo | Automated quality checks: routing, plan structure, code review |
| **After each agent turn** | Session Capture | Auto-promotes learnings every 30 min (throttled); runs after `session.idle` |
| **End of session** | Ogham + Obsidian | Inscribes session summary; archives completed work notes |
| **Observability** | Langfuse (optional) | Tracks token usage, latency, cost across sessions |
| **Temporal knowledge** | Graphiti (optional) | Stores entities and relationships with temporal metadata |

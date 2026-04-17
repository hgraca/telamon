# System Architecture

How Telamon's tools connect and what each provides at each stage of a session.

---

## System Flow

```
+------------------------------------------------------------------+
|                        Developer Machine                          |
|                                                                   |
|  +-----------+    +--------------------------------------+        |
|  | opencode  |<-->|              MCP Layer                |        |
|  |  (agent)  |    |  +--------+ +----------+ +---------+ |        |
|  +-----------+    |  | ogham  | | codebase-| |obsidian | |        |
|       |           |  |  MCP   | |   index  | |   MCP   | |        |
|       |           |  +---+----+ +-----+----+ +----+----+ |        |
|       |           +------+------------+----------+--------+        |
|       |                  |            |          |                 |
|       |          +-------v------+  +--v----+  +--v--------+       |
|       |          |  Postgres +  |  |Ollama |  | Obsidian  |       |
|       |          |  pgvector    |  |:11434 |  |   vault   |       |
|       |          +--------------+  +-------+  +-----------+       |
|       |                                                           |
|  +----v------------------------------------------------------+    |
|  |                   Host CLI Tools                          |    |
|  |  graphify  .  cass  .  rtk  .  ogham                      |    |
|  +-----------------------------------------------------------+    |
|                                                                   |
|  +---------------------------------------------------------------+|
|  |              OpenCode Plugins (always-on)                     ||
|  |  session-capture  .  graphify  .  rtk                         ||
|  +---------------------------------------------------------------+|
+-------------------------------------------------------------------+
```

---

## What each tool provides at each stage

| Stage | Tool | Role |
|---|---|---|
| **Session start** | Ogham | Recalls past decisions, bugs, and patterns for this project |
| **Session start** | Obsidian `brain/` | Loads goals, decisions, patterns, and known gotchas |
| **Session start** | QMD | Semantic vault search — surfaces related context before diving in |
| **Understanding code** | Graphify | Structural map: layers, god nodes, module relationships |
| **Finding code** | Codebase Index | Semantic search: *"where is the auth logic?"* |
| **Finding vault notes** | QMD | Semantic vault search: *"did we ever deal with X?"* |
| **Recovering past context** | cass | Searches previous agent session transcripts |
| **Writing code** | RTK | Compresses bash output to save tokens |
| **Long sessions** | Caveman | Reduces response verbosity ~75% on demand |
| **After significant work** | Ogham | Stores new decisions, patterns, bug fixes |
| **After significant work** | Obsidian | Promotes learnings to `brain/` notes |
| **After each agent turn** | Session Capture | Auto-promotes learnings every 30 min (throttled); runs after `session.idle` |
| **End of session** | Ogham + Obsidian | Inscribes session summary; archives completed work notes |

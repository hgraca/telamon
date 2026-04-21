---
layout: page
title: About
description: What Telamon is, why it exists, and where it's going.
---

## What is Telamon?

Telamon is an open-source **local infrastructure kit** for agentic software development.
It installs, wires up, and manages a suite of AI-augmentation tools so that your coding
agent has persistent memory, codebase understanding, and structured workflows — out of
the box.

Named after the mythological figure who supported the weight of the heavens, Telamon
supports the weight of context that coding agents need but constantly lose.

---

## The problem

Modern coding agents are powerful but forgetful. Every session starts from zero.
Decisions are re-explained, patterns are re-discovered, and bugs are re-encountered.

Developers spend significant time re-establishing context instead of building.
The agent ecosystem provides great models but poor infrastructure for **continuity**.

---

## The approach

Telamon takes a different path:

- **Local-first** — every tool runs on your machine. No cloud dependencies, no data leaving your network.
- **Install once, use everywhere** — one `make up` installs the entire stack. Wire up any project in seconds.
- **Memory as infrastructure** — agent memory isn't a feature request, it's a layer of the stack. Decisions, patterns, bugs, and session history persist across restarts.
- **Structured multi-agent workflows** — 10 specialized roles (architect, developer, tester, reviewer, PO, and more) with delegation protocols, not prompt chains.
- **Token-aware** — automatic compression keeps context within model limits without losing signal.

---

## What it includes

| Layer | Tools |
|---|---|
| **Persistent memory** | Ogham MCP, Postgres + pgvector, Ollama |
| **Codebase understanding** | Graphify (knowledge graph), Codebase Index (semantic search) |
| **Knowledge vault** | Obsidian MCP, QMD (semantic vault search) |
| **Session recall** | Cass (conversation search) |
| **Token efficiency** | RTK (output compression), Caveman (terse mode) |
| **Multi-agent** | 10 agent roles, slash commands, structured skills |
| **MCP integrations** | GitHub, Chrome DevTools, Playwright, ast-grep, Context7, Exa, grep.app |
| **Optional** | Langfuse (observability), Graphiti + Neo4j (temporal graph) |

---

## Who it's for

Telamon is built for developers who use AI coding agents daily and want:

- Continuity across sessions without re-explaining context
- A local, private setup with no cloud dependencies
- Structured workflows that go beyond chat-based prompting
- A single install that works across all their projects

---

## Status

Telamon is actively developed and used in production daily.
It currently targets [opencode](https://opencode.ai) as the primary coding agent, but any MCP-capable agent can use the memory and tool infrastructure.

---

## Links

- [GitHub repository](https://github.com/hgraca/telamon)
- [Developer Workflow]({{ '/developer-workflow' | relative_url }})
- [Tools documentation]({{ '/tools' | relative_url }})
- [Configuration guide]({{ '/configuration' | relative_url }})

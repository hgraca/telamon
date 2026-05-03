---
layout: page
title: Tools
description: Every tool Telamon installs and manages.
nav_section: docs
---

Every tool Telamon installs and manages — all local, all automatic.

## Memory & session

| Tool                                       | Description                                              |
|--------------------------------------------|----------------------------------------------------------|
| [Session Capture](remember-session)         | Auto-promotes learnings to memory before compaction      |
| [Diff Context](diff-context)               | Injects git change summary at session start              |
| [Active Work Context](active-work-context) | Injects active work items at session start, prompts user |
| [Compaction Save](compaction-save)         | Saves compaction timestamps to active work items         |

## Codebase understanding

| Tool                             | Description                                            |
|----------------------------------|--------------------------------------------------------|
| [Graphify](graphify)             | Auto-built structural knowledge graph of the codebase  |
| [Codebase Index](codebase-index) | Find code by natural language description              |
| [Repomix](repomix)               | Packs many files into a single compressed context dump |

## Knowledge vault

| Tool       | Description                              |
|------------|------------------------------------------|
| [QMD](qmd) | Semantic search over the knowledge vault |

## Token efficiency (optional)

| Tool               | Description                                           |
|--------------------|-------------------------------------------------------|
| [RTK](rtk)         | Compresses bash output before it reaches the LLM      |
| [Caveman](caveman) | Ultra-compressed communication (~75% token reduction) |

## Testing

| Tool                   | Description                                 |
|------------------------|---------------------------------------------|
| [promptfoo](promptfoo) | Automated quality checks for agent behavior |

## MCP integrations

| MCP Server          | Purpose                                       | Website                                                            |
|---------------------|-----------------------------------------------|--------------------------------------------------------------------|
| **GitHub**          | Issues, PRs, code search, reviews             | [github.com](https://github.com)                                   |
| **Chrome DevTools** | Browser inspection and debugging              | [developer.chrome.com](https://developer.chrome.com/docs/devtools) |
| **Playwright**      | Browser automation and testing                | [playwright.dev](https://playwright.dev)                           |
| **ast-grep**        | Structural code search using AST patterns     | [ast-grep.github.io](https://ast-grep.github.io)                   |
| **Context7**        | Library and framework documentation lookup    | [context7.com](https://context7.com)                               |
| **grep.app**        | Code search across public GitHub repositories | [grep.app](https://grep.app)                                       |
| **Exa**             | Web search                                    | [exa.ai](https://exa.ai)                                           |
| **git**             | Git operations (status, diff, commit, branch) | [git-scm.com](https://git-scm.com)                                 |

## Plugins

Plugins are OpenCode extensions that run automatically. They fire on specific events (session start, agent turn, bash call) to inject context or capture knowledge.

| Plugin                                     | What it does                                                                           | Source                                                                                                     |
|--------------------------------------------|----------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|
| [Session Capture](remember-session)         | Promotes learnings to memory after each turn and on wrap-up                            | [`remember-session.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/remember-session.js)         |
| [Diff Context](diff-context)               | Injects git change summary on first bash call                                          | [`diff-context.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/diff-context.js)               |
| [Graphify](graphify)                       | Injects god nodes and communities at session start                                     | [`graphify.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/graphify.js)                       |
| [RTK](rtk)                                 | Compresses bash output before it reaches the LLM                                       | [`rtk.ts`](https://github.com/hgraca/telamon/blob/main/src/plugins/rtk.ts)                                 |
| RTK Dedupe                                 | Deduplicates repeated output chunks from RTK                                           | [`rtk-dedupe.ts`](https://github.com/hgraca/telamon/blob/main/src/plugins/rtk-dedupe.ts)                   |
| [Script Runner](script-runner)             | Runs shell scripts and passes output to the LLM                                        | [`script-runner.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/script-runner.js)             |
| [Active Work Context](active-work-context) | Injects active work items at session start, prompts user to continue/archive/start new | [`active-work-context.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/active-work-context.js) |
| [Compaction Save](compaction-save)         | Saves compaction timestamps to active work items                                       | [`compaction-save.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/compaction-save.js)         |

Plugin source code lives in [`src/plugins/`](https://github.com/hgraca/telamon/tree/main/src/plugins).

## Optional services

| Tool                 | Description                                    | Website                                                          |
|----------------------|------------------------------------------------|------------------------------------------------------------------|
| [Langfuse](langfuse) | LLM observability — token usage, latency, cost | [langfuse.com](https://langfuse.com)                             |
| [Graphiti](graphiti) | Temporal knowledge graph backed by Neo4j       | [github.com/getzep/graphiti](https://github.com/getzep/graphiti) |

## Local LLM requirements

Some tools run models locally — no cloud API calls for these operations:

| Tool                             | Local model                                                      | Managed by       |
|----------------------------------|------------------------------------------------------------------|------------------|
| [Codebase Index](codebase-index) | Ollama `nomic-embed-text` (embeddings)                           | Docker container |
| [QMD](qmd)                       | `embeddinggemma`, `qwen3-reranker`, `qmd-query-expansion` (GGUF) | Self-managed     |
| [Graphify](graphify)             | Whisper (audio transcription, optional)                          | Python package   |

## Retired (evaluated and removed)

| Tool                   | Description                                        |
|------------------------|----------------------------------------------------|
| [Cass](cass)           | Conversation History Search                        |
| [Discord](discord)     | Discord bot (remote-opencode) — couldn't stabilize |
| [Ogham](ogham)         | Semantic memory store (pgvector) — replaced by QMD |
| [Obsidian](obsidian)   | Knowledge vault via MCP — replaced by QMD          |

## More

- [Plugins](plugins) — OpenCode plugins that extend agent capabilities

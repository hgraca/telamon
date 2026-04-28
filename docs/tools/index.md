---
layout: page
title: Tools
description: Every tool Telamon installs and manages.
nav_section: docs
---

Every tool Telamon installs and manages — all local, all automatic.

**Tier 1** = highest ROI, essential. **Tier 2** = high value, automatic setup. **Tier 3** = useful, value depends on usage habits.

## Memory & session

| Tool                               | Description                                             | Priority |
|------------------------------------|---------------------------------------------------------|----------|
| [Ogham MCP](ogham)                 | Stores and recalls decisions, bugs, patterns by meaning | Tier 1   |
| [Session Capture](session-capture) | Auto-promotes learnings to memory before compaction     | Built-in |
| [Diff Context](diff-context)       | Injects git change summary at session start             | Built-in |

## Codebase understanding

| Tool                             | Description                                            | Priority |
|----------------------------------|--------------------------------------------------------|----------|
| [Graphify](graphify)             | Auto-built structural knowledge graph of the codebase  | Tier 2   |
| [Codebase Index](codebase-index) | Find code by natural language description              | Tier 2   |
| [Repomix](repomix)               | Packs many files into a single compressed context dump | Tier 2   |

## Knowledge vault

| Tool                         | Description                                          | Priority |
|------------------------------|------------------------------------------------------|----------|
| [Obsidian MCP](obsidian-mcp) | Read/write bridge to a human-curated knowledge vault | Tier 3   |
| [QMD](qmd)                   | Semantic search over the Obsidian vault              | Tier 3   |

## Token efficiency (optional)

| Tool               | Description                                           | Priority |
|--------------------|-------------------------------------------------------|----------|
| [RTK](rtk)         | Compresses bash output before it reaches the LLM      | Tier 2   |
| [Caveman](caveman) | Ultra-compressed communication (~75% token reduction) | Tier 2   |

## Testing

| Tool                   | Description                                 | Priority |
|------------------------|---------------------------------------------|----------|
| [promptfoo](promptfoo) | Automated quality checks for agent behavior | Tier 2   |

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

| Plugin                             | What it does                                                | Source                                                                                             |
|------------------------------------|-------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| [Session Capture](session-capture) | Promotes learnings to memory after each turn and on wrap-up | [`session-capture.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/session-capture.js) |
| [Diff Context](diff-context)       | Injects git change summary on first bash call               | [`diff-context.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/diff-context.js)       |
| [Graphify](graphify)               | Injects god nodes and communities at session start          | [`graphify.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/graphify.js)               |
| [RTK](rtk)                         | Compresses bash output before it reaches the LLM            | [`rtk.ts`](https://github.com/hgraca/telamon/blob/main/src/plugins/rtk.ts)                         |
| RTK Dedupe                         | Deduplicates repeated output chunks from RTK                | [`rtk-dedupe.ts`](https://github.com/hgraca/telamon/blob/main/src/plugins/rtk-dedupe.ts)           |
| [Script Runner](script-runner)     | Runs shell scripts and passes output to the LLM             | [`script-runner.js`](https://github.com/hgraca/telamon/blob/main/src/plugins/script-runner.js)     |

Plugin source code lives in [`src/plugins/`](https://github.com/hgraca/telamon/tree/main/src/plugins).

## Optional services

| Tool                 | Description                                    | Website                                                          |
|----------------------|------------------------------------------------|------------------------------------------------------------------|
| [Langfuse](langfuse) | LLM observability — token usage, latency, cost | [langfuse.com](https://langfuse.com)                             |
| [Graphiti](graphiti) | Temporal knowledge graph backed by Neo4j       | [github.com/getzep/graphiti](https://github.com/getzep/graphiti) |

## Retired (evaluated and removed)

| Tool         | Description                 | Priority |
|--------------|-----------------------------|----------|
| [Cass](cass) | Conversation History Search | Tier 2   |

## More

- [Plugins](plugins) — OpenCode plugins that extend agent capabilities

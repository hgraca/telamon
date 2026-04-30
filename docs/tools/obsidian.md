---
layout: page
title: Obsidian (Retired)
description: Knowledge vault via Obsidian MCP — retired due to complexity and inferior querying.
nav_section: docs
---

# Obsidian (Retired)

Obsidian served as the knowledge vault interface, accessed via the Obsidian Local REST API community plugin running as an MCP server. Agents read and wrote brain notes, patterns, decisions, and gotchas through the Obsidian API.

**What it provided:**

- Read/write access to the memory vault through Obsidian's REST API
- Graph view for visualizing note relationships
- Community plugins for extended functionality

**Why it was retired:**

- **Complexity** — Required manual setup: installing Obsidian, enabling the Local REST API community plugin, configuring API keys, managing Docker containers to proxy the connection. Reinstalls wiped community plugins, breaking the integration.
- **Fragility** — The MCP server frequently failed to start (ECONNREFUSED on port 27124). Obsidian needed to be running with the plugin enabled for any agent memory access to work.
- **Inferior querying** — Obsidian does not provide semantic search. QMD offers hybrid semantic + keyword search (BM25 + vector), which is far more capable for agent memory retrieval.

**Replacement:** [QMD](qmd) — hybrid semantic + keyword search over the knowledge vault, fully local, no GUI dependency, no manual plugin setup.

---
layout: page
title: Obsidian MCP
description: Read/write bridge to a human-curated knowledge vault.
nav_section: docs
---

[Obsidian MCP](https://github.com/oleksandrkucherenko/obsidian-mcp) — Curated Knowledge Vault

Bridges the agent to an Obsidian vault containing long-lived, human-curated knowledge.
Each project gets its own vault subfolder:

```
<project>/bootstrap/       <- always-on context (loaded like AGENTS.md)
<project>/brain/
  memories.md              <- categorized lessons learned
  key_decisions.md         <- architectural decisions with rationale
  patterns.md              <- established codebase conventions
  gotchas.md               <- traps, constraints, known issues
<project>/work/active/     <- in-progress work notes
<project>/work/archive/    <- completed work notes
<project>/reference/       <- architecture maps, flow docs
<project>/thinking/        <- scratchpad for drafts
```

High value if you maintain notes. If nobody writes docs it adds nothing.

> After install, the Obsidian *Local REST API* community plugin must be enabled manually — the installer walks you through the steps.

**MCP tools:** `obsidian_search`, `obsidian_semantic_search`, `get_note_content`

**Priority:** Tier 3

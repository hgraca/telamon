---
layout: page
title: RTK
description: Token compression proxy — compresses bash output before it reaches the LLM.
nav_section: docs
---

[RTK](https://github.com/rtk-ai/rtk) — Token Compression Proxy

Transparently compresses bash command output before it reaches the LLM.
Installed as an opencode plugin that auto-patches shell commands.

- Zero configuration; works transparently
- Highest ROI for token efficiency — immediate, compounds with all other tools
- Companion plugin (`rtk-dedupe.ts`) deduplicates repeated output chunks

**Type:** Built-in OpenCode plugin (`src/plugins/rtk.ts`, `src/plugins/rtk-dedupe.ts`)

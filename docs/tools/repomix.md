---
layout: page
title: Repomix
description: Packs many files into a single compressed context dump.
nav_section: docs
---

[Repomix](https://github.com/yamadashy/repomix) — Directory Context Packer

Packs directory contents into a single compressed context dump using Tree-sitter-aware chunking.
~70% token reduction compared to reading files individually.

- Replaces 5+ individual file reads with a single structured dump
- Language-aware chunking preserves code structure
- Security scanning detects secrets before context is sent to the model

Do **not** combine with Codebase Index for the same files — redundant context wastes tokens.

**MCP tools:** `pack_codebase`, `pack_remote_repository`, `generate_skill`, `attach_packed_output`, `read_repomix_output`, `grep_repomix_output`

**Priority:** Tier 2

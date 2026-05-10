---
name: repomix
description: "Pack directory contents into single compressed context for LLM consumption. Use when reading 5+ files from same area, need full module context, or want token-efficient codebase snapshots. Prefer over multi-file reads for broad context gathering."
---

# Repomix

Packs directories or file sets into structured XML with Tree-sitter compression (~70% token reduction vs reading files individually). Runs as MCP server via `npx -y repomix --mcp`.

## When to Use

| Situation | Tool |
|-----------|------|
| Reading 5+ files in same directory | **Repomix** |
| Need full module/feature context | **Repomix** |
| Exploring unfamiliar codebase area | **Repomix** |
| Searching by meaning across whole codebase | codebase-index |
| Finding specific function/class definition | codebase-index |
| Reading 1–3 specific files, need exact line numbers for editing | Individual file reads |

**NEVER use both Repomix AND codebase-index for the same files** — duplicate context wastes tokens.

## MCP Tools

The Repomix MCP server exposes tools for:

- **Pack directory** — compress a directory (or file list) into XML context
- **File tree** — read directory structure without file contents
- **Search** — search within packed codebase

Verify exact tool names via Repomix docs: https://github.com/yamadashy/repomix  
Or inspect what `npx -y repomix --mcp` exposes at runtime.

## Output Format

XML with line numbers. Comments preserved. Structured sections per file.

Custom ignore patterns (applied via `repomix.config.json`) exclude:
- `vendor/`, `node_modules/`, `storage/`
- `*no-vcs*` (project rule — never read these)

## Config

`repomix.config.json` in project root is applied automatically. Example:

```json
{
  "output": { "style": "xml", "compress": true },
  "ignore": { "customPatterns": ["*no-vcs*", "storage/"] }
}
```

## Security Scanning

Repomix refuses to pack directories containing detected secrets (API keys, passwords, `.env` files).

If packing fails with a security error:
1. Check if directory contains `.env` or credentials files
2. Use `--no-security-check` **only after verifying no secrets will leak**
3. Prefer excluding the secrets file via `ignore.customPatterns`

## Installation

Installed by `bin/install.sh` (POST_DOCKER_APPS). Initialised per-project by `bin/init.sh` (writes `repomix.config.json`).

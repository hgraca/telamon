---
name: repomix
description: "Pack directory contents into single compressed context for LLM consumption. Use when reading 5+ files from same area, need full module context, or want token-efficient codebase snapshots. Prefer over multi-file reads for broad context gathering."
---

# Repomix

Packs directories or file sets into structured XML with Tree-sitter compression (~70% token reduction vs reading files individually). Runs as CLI via `repomix pack`.

## When to Use

| Situation                                                       | Tool                  |
|-----------------------------------------------------------------|-----------------------|
| Reading 5+ files in same directory                              | **Repomix**           |
| Need full module/feature context                                | **Repomix**           |
| Exploring unfamiliar codebase area                              | **Repomix**           |
| Searching by meaning across whole codebase                      | codebase-index        |
| Finding specific function/class definition                      | codebase-index        |
| Reading 1–3 specific files, need exact line numbers for editing | Individual file reads |

**NEVER use both Repomix AND codebase-index for same files** — duplicate context wastes tokens.

## CLI Usage

```bash
repomix pack <directory>                          # Pack directory, output XML to stdout
repomix pack <directory> --output output.xml      # Write to file
repomix pack <directory> --style markdown          # Markdown output
repomix pack <directory> --style json              # JSON output
repomix pack <directory> --compress                # Tree-sitter compression (~70% token savings)
repomix pack <directory> --include "src/Auth/**"   # Filter by include patterns
repomix pack --remote <github-url>                 # Pack remote GitHub repo
```

## Output Format

XML with line numbers. Comments preserved. Structured sections per file.

Custom ignore patterns (applied via `repomix.config.json`) exclude:
- `vendor/`, `node_modules/`, `storage/`
- `*no-vcs*` (project rule — never read these)

## Config

`repomix.config.json` in project root applied automatically. Example:

```json
{
  "output": { "style": "xml", "compress": true },
  "ignore": { "customPatterns": ["*no-vcs*", "storage/"] }
}
```

## Security Scanning

Repomix refuses to pack directories containing detected secrets (API keys, passwords, `.env` files).

If packing fails with security error:
1. Check if directory contains `.env` or credentials files
2. Use `--no-security-check` **only after verifying no secrets will leak**
3. Prefer excluding secrets file via `ignore.customPatterns`

## Installation

Installed by `bin/install.sh` (POST_DOCKER_APPS). Initialised per-project by `bin/init.sh` (writes `repomix.config.json`).
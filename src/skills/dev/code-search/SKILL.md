---
name: telamon.code_search
description: "Code search tool selection guide. Use when you need to find code, understand architecture, locate definitions, or explore the codebase. Helps choose the right tool for each search scenario."
---

# Code Search

Selects the right search tool for the question. Different tools excel at different queries — using the wrong one wastes tokens or misses results.

## When to Apply

- Finding code by meaning, keyword, or structure
- Locating definitions, callers, or implementations
- Understanding architecture or dependencies across files
- Exploring an unfamiliar codebase area
- Packing code for full-context analysis

## Tool Selection

| Question type | Tool | Why |
|---|---|---|
| Semantic search ("where is auth logic?") | `codebase_search` | Hybrid semantic + keyword, returns full code content |
| Quick location lookup ("find the payment handler") | `codebase_peek` | Same search, returns only metadata — saves ~90% tokens |
| Jump to definition ("where is validateToken defined?") | `implementation_lookup` | Finds authoritative source, skips tests/docs/examples |
| Who calls this? / What does this call? | `call_graph` | Traces callers or callees by function name |
| Find similar code (duplicate detection, refactoring) | `find_similar` | Vector similarity on a code snippet |
| File path lookup by pattern | `Glob` | Fast glob matching (`**/*.ts`, `src/**/Handler.php`) |
| Exact string or regex in file contents | `Grep` | Regex search across files, filterable by extension |
| AST structural pattern matching | `ast-grep` | Matches code by AST structure, not text |
| Cross-file relationships, architecture | `graphify` (MCP) | Knowledge graph with communities, god nodes, paths |
| Full directory context for audit/analysis | `repomix` (MCP) | Packs files into single structured dump |

## Detailed Guidance

### codebase-index (opencode-index)

Semantic + keyword hybrid search. Best general-purpose code finder.

**Use when:**
- "Where is authentication logic?"
- "Find the function that validates user permissions"
- "How is the event bus configured?"

**Tools:**
- `codebase_search` — full code content in results
- `codebase_peek` — metadata only (file, line, name, type) — prefer when you just need locations
- `implementation_lookup` — jump to where a symbol is defined (prefers real code over tests)
- `call_graph` — trace callers/callees of a function
- `find_similar` — find code similar to a given snippet

**Tips:**
- Describe behavior, not syntax: "function that sends welcome emails" not "sendWelcomeEmail"
- Filter by `chunkType` (function, class, method, interface) to narrow results
- Filter by `directory` or `fileType` when you know the area
- Use `codebase_peek` first when you only need to know WHERE code is, then `Read` to get content

### graphify (MCP)

Knowledge graph with cross-file relationships, community detection, and graph traversal.

**Use when:**
- "What calls this function?" (cross-file)
- "How does module A depend on module B?"
- Understanding architecture and dependencies
- Refactoring that spans multiple files
- Searching mixed content (code + docs + PDFs + recordings)

**Tools:**
- `graphify_query_graph` — BFS/DFS traversal from a concept
- `graphify_get_node` — full details for a specific node
- `graphify_get_neighbors` — direct connections of a node
- `graphify_get_community` — all nodes in a community cluster
- `graphify_god_nodes` — most-connected nodes (core abstractions)
- `graphify_shortest_path` — path between two concepts

**Tips:**
- Use BFS (`mode: bfs`) for broad context ("what connects to X?")
- Use DFS (`mode: dfs`) to trace a specific dependency chain
- Check `god_nodes` first when exploring unfamiliar architecture
- Set `token_budget` to control output size

### repomix (MCP)

Packs directory contents into a single structured file for full-context analysis.

**Use when:**
- Full audit of a module or directory
- Generating complete architecture documents
- Packing all (or selected) files with directory structure
- Reading 5+ files from same area (more efficient than individual reads)
- Need complete module context for a review or refactoring plan

**Tools:**
- `repomix_pack_codebase` — pack a local directory
- `repomix_pack_remote_repository` — pack a GitHub repo
- `repomix_grep_repomix_output` — search within packed output
- `repomix_read_repomix_output` — read sections of packed output

**Tips:**
- Use `includePatterns` to focus on relevant files (`"src/Auth/**"`)
- Use `compress: true` for large repos (Tree-sitter compression, ~70% token savings)
- Never use both repomix AND codebase-index for the same files — wastes tokens

### Glob

Fast file path matching by pattern.

**Use when:**
- Finding files by name or extension
- Listing all files in a directory matching a pattern
- "Find all migration files", "list all test files for auth"

**Tips:**
- Use `**/*.php` for recursive, `*.php` for current directory only
- Results sorted by modification time (newest first)

### Grep

Regex content search across files.

**Use when:**
- Searching for exact strings or regex patterns
- Finding all usages of a specific class/function name
- Filtering by file extension with `include` parameter

**Tips:**
- Supports full regex: `"function\\s+\\w+"`, `"log.*Error"`
- Use `include` to narrow: `"*.php"`, `"*.{ts,tsx}"`
- Returns file paths + line numbers, sorted by modification time

### ast-grep

AST-based structural pattern matching.

**Use when:**
- Matching code structure regardless of formatting or variable names
- Finding all functions with a specific signature pattern
- Structural refactoring queries

**Tips:**
- Pattern must be valid AST structure for the language
- Auto-detects language from file extensions
- Use `lang` parameter to force language when ambiguous

## Decision Flowchart

1. **Know the exact file path?** → `Read`
2. **Know a file name pattern?** → `Glob`
3. **Know an exact string to find?** → `Grep`
4. **Need structural code pattern?** → `ast-grep`
5. **Need to find code by meaning?** → `codebase_search` / `codebase_peek`
6. **Need to find a definition?** → `implementation_lookup`
7. **Need callers/callees?** → `call_graph`
8. **Need cross-file architecture?** → `graphify`
9. **Need full directory context?** → `repomix`

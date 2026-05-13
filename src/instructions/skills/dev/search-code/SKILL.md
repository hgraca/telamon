---
name: telamon.search_code
description: "Code search tool selection guide. Use when you need to find code, understand architecture, locate definitions, or explore codebase. Helps choose right tool for each search scenario."
---

# Code Search

Selects right search tool for question. Different tools excel at different queries — using wrong one wastes tokens or misses results.

## When to Apply

- Finding code by meaning, keyword, or structure
- Locating definitions, callers, or implementations
- Understanding architecture or dependencies across files
- Exploring unfamiliar codebase area
- Packing code for full-context analysis

## Tool Selection

| Question type                                          | Tool                    | Why                                                    |
|--------------------------------------------------------|-------------------------|--------------------------------------------------------|
| Semantic search ("where is auth logic?")               | `codebase_search`       | Hybrid semantic + keyword, returns full code content   |
| Quick location lookup ("find payment handler")         | `codebase_peek`         | Same search, returns only metadata — saves ~90% tokens |
| Jump to definition ("where is validateToken defined?") | `implementation_lookup` | Finds authoritative source, skips tests/docs/examples  |
| Who calls this? / What does this call?                 | `call_graph`            | Traces callers or callees by function name             |
| Find similar code (duplicate detection, refactoring)   | `find_similar`          | Vector similarity on code snippet                      |
| File path lookup by pattern                            | `Glob`                  | Fast glob matching (`**/*.ts`, `src/**/Handler.php`)   |
| Exact string or regex in file contents                 | `Grep`                  | Regex search across files, filterable by extension     |
| AST structural pattern matching                        | `ast-grep`              | Matches code by AST structure, not text                |
| Cross-file relationships, architecture                 | `graphify` (MCP)        | Knowledge graph with communities, god nodes, paths     |
| Full directory context for audit/analysis              | `repomix` (MCP)         | Packs files into single structured dump                |
| Markdown notes/docs in memory vault                    | `qmd_*` (MCP)           | Hybrid lex+vec+rerank over indexed `.md` collections   |

## Detailed Guidance

### codebase-index (opencode-index)

Semantic + keyword hybrid search. Best general-purpose code finder.

**Use when:**
- "Where is authentication logic?"
- "Find function that validates user permissions"
- "How is event bus configured?"

**Tools:**
- `codebase_search` — full code content in results
- `codebase_peek` — metadata only (file, line, name, type) — prefer when you just need locations
- `implementation_lookup` — jump to where symbol defined (prefers real code over tests)
- `call_graph` — trace callers/callees of function
- `find_similar` — find code similar to given snippet

**Tips:**
- Describe behavior, not syntax: "function that sends welcome emails" not "sendWelcomeEmail"
- Filter by `chunkType` (function, class, method, interface) to narrow results
- Filter by `directory` or `fileType` when you know area
- Use `codebase_peek` first when you only need to know WHERE code is, then `Read` to get content

### graphify (MCP)

Knowledge graph with cross-file relationships, community detection, and graph traversal.

**Use when:**
- "What calls this function?" (cross-file)
- "How does module A depend on module B?"
- Understanding architecture and dependencies
- Refactoring spanning multiple files
- Searching mixed content (code + docs + PDFs + recordings)

**Tools:**
- `graphify_query_graph` — BFS/DFS traversal from concept
- `graphify_get_node` — full details for specific node
- `graphify_get_neighbors` — direct connections of node
- `graphify_get_community` — all nodes in community cluster
- `graphify_god_nodes` — most-connected nodes (core abstractions)
- `graphify_shortest_path` — path between two concepts

**Tips:**
- Use BFS (`mode: bfs`) for broad context ("what connects to X?")
- Use DFS (`mode: dfs`) to trace specific dependency chain
- Check `god_nodes` first when exploring unfamiliar architecture
- Set `token_budget` to control output size

### repomix (MCP)

Packs directory contents into single structured file for full-context analysis.

**Use when:**
- Full audit of module or directory
- Generating complete architecture documents
- Packing all (or selected) files with directory structure
- Reading 5+ files from same area (more efficient than individual reads)
- Need complete module context for review or refactoring plan

**Tools:**
- `repomix_pack_codebase` — pack local directory
- `repomix_pack_remote_repository` — pack GitHub repo
- `repomix_grep_repomix_output` — search within packed output
- `repomix_read_repomix_output` — read sections of packed output

**Tips:**
- Use `includePatterns` to focus on relevant files (`"src/Auth/**"`)
- Use `compress: true` for large repos (Tree-sitter compression, ~70% token savings)
- Never use both repomix AND codebase-index for same files — wastes tokens

### Glob

Fast file path matching by pattern.

**Use when:**
- Finding files by name or extension
- Listing all files in directory matching pattern
- "Find all migration files", "list all test files for auth"

**Tips:**
- Use `**/*.php` for recursive, `*.php` for current directory only
- Results sorted by modification time (newest first)
- **Gitignored paths not surfaced** by `Glob` (or by `find` from repo root in shell pipelines respecting `.gitignore`). Files under `storage/`, `vendor/`, and other gitignored areas return zero matches even when they exist. To search gitignored areas, use `Read` with known canonical path, or `bash` with explicit absolute path (`ls /abs/path` or `find /abs/path -type f`), or `rg --no-ignore` for content search. See [[gotchas]] entry "Glob and find miss gitignored paths".

### Grep

Regex content search across files.

**Use when:**
- Searching for exact strings or regex patterns
- Finding all usages of specific class/function name
- Filtering by file extension with `include` parameter

**Tips:**
- Supports full regex: `"function\\s+\\w+"`, `"log.*Error"`
- Use `include` to narrow: `"*.php"`, `"*.{ts,tsx}"`
- Returns file paths + line numbers, sorted by modification time

### qmd (MCP)

Hybrid markdown search over memory vault — combines BM25 keyword (`lex`), semantic vector (`vec`), and hypothetical-document (`hyde`) search with LLM reranking.

**Use when:**
- Searching `.md` content under `.ai/telamon/memory/` (brain notes, ADRs, PDRs, gotchas, patterns, work artefacts, decisions, retrospectives)
- Looking up past lessons, decisions, or context from vault
- Reading vault files by canonical path (`qmd_get` works on gitignored `.ai/` paths where `Glob` does not)
- Concept search across notes ("how did we decide X?", "what's auth pattern?")

**Tools:**
- `qmd_query` — hybrid lex+vec+hyde search across collections
- `qmd_get` — read single document by path or docid
- `qmd_multi_get` — batch fetch by glob or comma-separated paths
- `qmd_status` — list indexed collections and health

**Indexed collections:**
- `telamon` — entire memory vault (brain, work, project-rules, reference, thinking, bootstrap)
- Root: `<project>/.ai/telamon/memory` (symlink into `storage/projects-memory/<project>/`)

**Tips:**
- For exact term/path lookup, use `lex` only: `[{ "type": "lex", "query": "PDRs gotcha" }]`
- For concept search, combine `lex` + `vec` for best recall
- Filter by `collections: ["telamon"]` to scope to this project's vault
- Prefer `qmd_*` over `Glob`/`Grep` for ANY `.md` content search inside `.ai/telamon/memory/` — qmd's index is canonical view of vault, and `Glob`/`Grep` may miss gitignored vault paths
- For non-vault markdown (e.g. project-root `README.md`, `docs/**/*.md`), `Glob`/`Grep`/`Read` are still right tools — qmd does not index those

### ast-grep

AST-based structural pattern matching.

**Use when:**
- Matching code structure regardless of formatting or variable names
- Finding all functions with specific signature pattern
- Structural refactoring queries

**Tips:**
- Pattern must be valid AST structure for language
- Auto-detects language from file extensions
- Use `lang` parameter to force language when ambiguous

## Decision Flowchart

1. **Searching `.md` content under `.ai/telamon/memory/`?** → `qmd_query` / `qmd_get`
2. **Know exact file path?** → `Read`
3. **Know file name pattern?** → `Glob`
4. **Know exact string to find?** → `Grep`
5. **Need structural code pattern?** → `ast-grep`
6. **Need to find code by meaning?** → `codebase_search` / `codebase_peek`
7. **Need to find definition?** → `implementation_lookup`
8. **Need callers/callees?** → `call_graph`
9. **Need cross-file architecture?** → `graphify`
10. **Need full directory context?** → `repomix`
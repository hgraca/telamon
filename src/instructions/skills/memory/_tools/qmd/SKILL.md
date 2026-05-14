---
name: qmd
description: Search markdown knowledge bases, notes, and documentation using QMD. Use when users ask to search notes, find documents, or look up information.
license: MIT
compatibility: Requires qmd CLI or MCP server. Install via `npm install -g @tobilu/qmd`.
metadata:
  author: tobi
  version: "2.0.0"
allowed-tools: Bash(qmd:*)
---

# QMD - Quick Markdown Search

Local search engine for markdown content.

## Status

!`qmd status 2>/dev/null || echo "Not installed: npm install -g @tobilu/qmd"`

## CLI Usage

Set environment before running qmd commands to use Telamon's storage and GPU:

```bash
export XDG_CACHE_HOME="${TELAMON_ROOT}/storage"
export QMD_LLAMA_GPU=true

qmd query "CAP theorem consistency"              # Auto-expand + rerank
qmd query $'lex: CAP theorem\nvec: tradeoff between consistency and availability'  # Structured
qmd search "CAP theorem"                          # BM25 only (no LLM)
qmd get "#abc123"                                 # By docid
qmd multi-get "journals/2026-*.md" -l 40          # Batch pull snippets
qmd status                                        # Collections and health
```

Or inline for one-off commands:

```bash
XDG_CACHE_HOME="${TELAMON_ROOT}/storage" QMD_LLAMA_GPU=true qmd query "question"
```

Or inline for one-off commands:

```bash
XDG_CACHE_HOME="${TELAMON_ROOT}/storage" QMD_LLAMA_GPU=true qmd query "question"
```

### Query Types

| Type   | Method | Input                                       |
|--------|--------|---------------------------------------------|
| `lex`  | BM25   | Keywords — exact terms, names, code         |
| `vec`  | Vector | Question — natural language                 |
| `hyde` | Vector | Answer — hypothetical result (50-100 words) |

### Writing Good Queries

**lex (keyword)**
- 2-5 terms, no filler words
- Exact phrase: `"connection pool"` (quoted)
- Exclude terms: `performance -sports` (minus prefix)
- Code identifiers work: `handleError async`

**vec (semantic)**
- Full natural language question
- Be specific: `"how does the rate limiter handle burst traffic"`
- Include context: `"in the payment service, how are refunds processed"`

**hyde (hypothetical document)**
- Write 50-100 words of what *answer* looks like
- Use vocabulary you expect in result

**expand (auto-expand)**
- Use single-line query (implicit) or `expand: question` on its own line
- Lets local LLM generate lex/vec/hyde variations
- Do not mix `expand:` with other typed lines — either standalone expand query or full query document

### Intent (Disambiguation)

When query term ambiguous, add `intent` to steer results:

```json
{
  "searches": [
    { "type": "lex", "query": "performance" }
  ],
  "intent": "web page load times and Core Web Vitals"
}
```

Intent affects expansion, reranking, chunk selection, and snippet extraction. Does not search on its own — steering signal that disambiguates queries like "performance" (web-perf vs team health vs fitness).

### Combining Types

| Goal                  | Approach                                            |
|-----------------------|-----------------------------------------------------|
| Know exact terms      | `lex` only                                          |
| Don't know vocabulary | Use single-line query (implicit `expand:`) or `vec` |
| Best recall           | `lex` + `vec`                                       |
| Complex topic         | `lex` + `vec` + `hyde`                              |
| Ambiguous query       | Add `intent` to any combination above               |

First query gets 2x weight in fusion — put best guess first.

### Lex Query Syntax

| Syntax     | Meaning      | Example                      |
|------------|--------------|------------------------------|
| `term`     | Prefix match | `perf` matches "performance" |
| `"phrase"` | Exact phrase | `"rate limiter"`             |
| `-term`    | Exclude      | `performance -sports`        |

Note: `-term` only works in lex queries, not vec/hyde.

### Collection Filtering

```json
{ "collections": ["docs"] }              // Single
{ "collections": ["docs", "notes"] }     // Multiple (OR)
```

Omit to search all collections.

## Setup

```bash
npm install -g @tobilu/qmd
qmd collection add ~/notes --name notes
qmd embed
```

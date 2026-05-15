---
name: telamon.explore-project
description: "Explores the entire project and produces a technical description at .ai/telamon/memory/bootstrap/project.md covering structure, purpose, architecture, conventions, and known inconsistencies. Use when onboarding to a new project, when the description is missing or stale, when the user says 'explore the project', 'describe the project', 'map the codebase', 'document the architecture', or invokes /explore-project. Also use when starting work on an unfamiliar repo and a project map is needed before planning."
---

# Skill: Explore Project

Produce concise, technical project description any agent or human can load at session start to understand
*what this project is*, *how laid out*, and *where rough edges are*. Output: one file
`.ai/telamon/memory/bootstrap/project.md`.

Differentiator from `telamon.audit_codebase`: this is one-page map, not findings report. Rough edges
named in one line each so future work has context — diagnosing and fixing them out of scope.

## When to Apply

- New project initialised and `description.md` missing or empty.
- Existing `description.md` stale (repository drifted significantly).
- User explicitly asks to explore, describe, or map project.
- Before planning large initiative in unfamiliar codebase.

## Procedure

### Step 1: Check existing state

Read `.ai/telamon/memory/bootstrap/project.md` if exists. Treat every claim as hypothesis to
verify against codebase (source of truth). Note assertions to confirm or refute during exploration.

### Step 2: Survey repository

Build mental model by reading files in this order. Stop expanding into folder once its purpose clear —
exhaustive reads wasteful.

0. **Knowledge graph (if available)**: if `graphify-out/graph.json` exists, query graph first for fast
   architectural overview — compresses relationship-heavy parts into few calls.
   Run `graphify-report` to confirm graph populated and surface god nodes, communities, and stats.
   Then use `graphify query "<question>"` (CLI) or MCP tools (`graphify_god_nodes`,
   `graphify_graph_stats`, `graphify_query_graph`) for concept-level questions (e.g. "entry points",
   "data stores", "auth"). Treat graph output as hypothesis layer — still verify against codebase.
   If `graphify` unavailable or graph empty/stale, skip and proceed with file-based survey.
   See `telamon.graphify`.
1. **Top-level orientation**: `README.md`, `AGENTS.md`, `CLAUDE.md`, `Makefile`, `package.json` / `composer.json` /
   `pyproject.toml` / `Cargo.toml`, `.gitignore`, `docker-compose.yml`, `.env.dist`.
2. **Directory shape**: list root and one level deep. Identify which folders hold source, tests, config,
   scripts, docs, vendored code, runtime data.
3. **Entry points**: scripts in `bin/`, `scripts/`, `cmd/`, framework bootstraps (`public/index.php`,
   `src/main.ts`, `manage.py`, `main.go`, …).
4. **Architecture artefacts**: `docs/architecture*.md`, ADRs (`docs/adr/`, `.ai/adr/`), `.ai/telamon/memory/latent/ADRs/`,
   `.ai/telamon/memory/latent/PDRs/`.
5. **Source tree**: sample one or two representative files per major component to confirm patterns (layering,
   naming, framework usage). Use `repomix` or `codebase-peek` to bulk-scan when many files belong to same
   concern — see `telamon.search_code` for tool selection.
6. **Tests**: locate test root, identify framework, note layering convention (unit/integration/e2e).
7. **CI/CD and tooling**: `.github/workflows/`, `.gitlab-ci.yml`, `Dockerfile*`, `Makefile` targets, lint/format config.

Prefer broad coverage over depth. If folder gitignored or marked `no-vcs`, skip (see `ignore.md`).

**`.ai/` directory**: holds agent-only artefacts (memory vault, planning issue folders,
thinking/scratch, project rules). **Gitignored by convention** — nothing under `.ai/` committed to
project repository. Treat as local working state for agents, not as project source. When writing
description, mention `.ai/` under *Repository layout* (one row, noting "agent working state, gitignored")
and under *Critical conventions* (rule that `.ai/` contents never committed). Do not enumerate its
sub-structure — that belongs to `telamon.memory_management`.

### Step 3: Identify what may be problematic

While exploring, capture observations under these categories. **Be specific** — cite paths. **Be brief** —
one line each. Do not fix anything; this is reconnaissance.

- **Inconsistencies**: two patterns for same concern (e.g. two HTTP clients, two test styles, mixed naming).
- **Architectural drift**: dependencies flowing wrong way, framework code in domain layers, god modules.
- **Stale or orphaned**: directories with no recent commits, dead config, TODO/FIXME clusters.
- **Risky areas**: missing tests, weak types, security-sensitive code without review, manual deploy steps.
- **Convention gaps**: behaviour exists but undocumented, or docs disagree with code.

If category has no findings, omit it. Do not pad.

### Step 4: Write description

Write result to `.ai/telamon/memory/bootstrap/project.md`, overwriting previous content. After writing, run `format-md` on file to align table columns.

Follow template below. Adjust section titles to fit project, but keep section order: *purpose →
layout → architecture → lifecycle/workflows → conventions → rough edges → pointers*. This order
is what agent needs in roughly order it needs it.

Constraints on output:

- **Length**: target 80–150 lines. Hard cap 200. Density over completeness.
- **Voice**: technical, declarative, present tense. No marketing adjectives. No hedging.
- **Tables for layouts**: directory tables, file/role tables. Tables compress better than prose.
- **Cite paths**: every architectural claim points at file or folder.
- **No procedures**: do not document *how* to install/build/test in detail — link to canonical doc instead.
- **Flag, do not solve**: *Rough edges* section names problems without prescribing fixes.

### Step 5: Optimize for agent consumption

Deliverable loaded into every future agent session — token cost compounds. Run two passes:

1. **Structure pass** — load `telamon.optimize-instructions` and apply its writing-rules checklist (economy,
   precision, non-redundant, scoped) to description. Drop hedging, collapse prose into tables where
   possible, remove anything agent cannot act on.
2. **Compression pass** — load `caveman` (full intensity) and rewrite description in caveman style.
   Preserve all paths, identifiers, and technical claims verbatim; compress only connective tissue.
   Output remains valid Markdown; only prose voice changes.

### Step 6: Verify and report

1. Re-read written file. Confirm every architectural claim maps to real path and no path mangled
   by compression pass.
2. Run `wc -l` on file. If over 200 lines, compress further before reporting.
3. Report to caller using `telamon.agent-communication` `FINISHED` signal. Include: file path,
   line count, and 3-bullet recap (what project *is*, its dominant architectural pattern, top rough edge).

If exploration cannot proceed (repo unreadable, no source detected, write target inaccessible), follow
`telamon.exception-handling` and emit `BLOCKED` with specific cause and what needed to unblock.

## Template

> ---
> tags: [bootstrap, project]
> description: What \<Project\> is, how repo laid out, key conventions and rough edges
> ---
>
> ## What this project is
>
> One paragraph: what project does, who it for, what makes distinctive. Name primary
> language(s), runtime, and any framework that shapes whole repo.
>
> ## Repository layout
>
> | Path | Contents |
> |------|----------|
> | `<path>` | <one-line purpose> |
>
> Cover every top-level folder that matters. Group trivial folders into one row.
>
> ## Architecture
>
> Describe dominant pattern (layered, hexagonal, MVC, modular monolith, microservices, …) and actual
> module/component boundaries. Note direction of dependencies. If project follows documented
> pattern (e.g. DDD + Hexagonal), name it and point at canonical doc.
>
> Sub-bullets for: entry points, data stores, external services, key cross-cutting concerns (auth, logging,
> messaging).
>
> ## Lifecycle & workflows
>
> _(Optional — include only if project has non-obvious lifecycles like install/init/update, multi-stage
> deploy, or release pipelines worth knowing up front.)_
>
> Brief, numbered. Link to canonical doc rather than reproducing.
>
> ## Critical conventions
>
> Bullet list. Each bullet is one rule contributor must know that is not obvious from code. Examples:
> dist vs runtime config files, gitignore patterns, symlinked paths, files-not-to-read, naming rules.
>
> ## Rough edges
>
> _(Omit if none found.)_
>
> Brief, factual. One bullet per observation. Examples:
>
> - Two test styles coexist: `tests/unit/` uses Pest, `tests/Feature/` uses PHPUnit.
> - `src/legacy/` has no tests and referenced by `src/api/v1/`.
> - `docs/architecture.md` describes v1 layout; code has since moved to v2 (see `src/v2/`).
>
> Do not propose fixes here.
>
> ## When to read docs vs code
>
> Pointers table: for question type → go to file/folder. Helps future agents skip exploration.

## Tools

Prefer these tools for efficient exploration:

- `graphify` — query codebase knowledge graph for architecture, core abstractions, and concept paths.
  Use first when available; see `telamon.graphify`.
- `repomix` — bulk-pack folder when needing broad context across many files in one area.
- `codebase-index` (`codebase_peek`, `codebase_search`) — locate concepts and definitions semantically.
- `glob` / `grep` — exact filename and pattern lookup.
- `ast-grep` — structural code search when prose grep ambiguous.

See `telamon.search_code` for choosing between them.

## MUST

- Write final description to `.ai/telamon/memory/bootstrap/project.md` and nowhere else.
- Overwrite existing file in place — this is canonical project map.
- Cite real paths for every architectural claim; verify each path exists before writing.
- Run `telamon.optimize-instructions` pass before compression pass — order matters; compressing
  unstructured prose loses information.
- Run `caveman` compression pass on final document; paths and identifiers stay verbatim.
- Keep file at or under 200 lines; aim for 80–150 *after* compression.
- End with `FINISHED` signal containing file path, line count, and 3-bullet recap.

## MUST NOT

- Write to any other location, or create supporting files in `bootstrap/`.
- Include install/build/test step-by-step instructions — link to canonical doc.
- Recommend fixes in *Rough edges* section; flag only.
- Read or describe files marked `no-vcs` or excluded by `ignore.md`.
- Pad with marketing language, aspirations, or generic best-practice advice.
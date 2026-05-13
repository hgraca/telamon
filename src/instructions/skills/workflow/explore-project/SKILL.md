---
name: telamon.explore-project
description: "Explores the entire project and produces a technical description at .ai/telamon/memory/project-rules/description.md covering structure, purpose, architecture, conventions, and known inconsistencies. Use when onboarding to a new project, when the description is missing or stale, when the user says 'explore the project', 'describe the project', 'map the codebase', 'document the architecture', or invokes /explore-project. Also use when starting work on an unfamiliar repo and a project map is needed before planning."
---

# Skill: Explore Project

Produce a concise, technical project description that any agent or human can load at session start to understand
*what this project is*, *how it is laid out*, and *where the rough edges are*. The output is one file:
`.ai/telamon/memory/project-rules/description.md`.

Differentiator from `telamon.audit_codebase`: this is a one-page map, not a findings report. Rough edges are
named in one line each so future work has context — diagnosing and fixing them is out of scope.

## When to Apply

- A new project has been initialised and `description.md` is missing or empty.
- The existing `description.md` is stale (repository has drifted significantly).
- The user explicitly asks to explore, describe, or map the project.
- Before planning a large initiative in an unfamiliar codebase.

## Procedure

### Step 1: Check existing state

Read `.ai/telamon/memory/project-rules/description.md` if it exists. Treat every claim as a hypothesis to
verify against the codebase, which is the source of truth. Note assertions to confirm or refute during
exploration.

### Step 2: Survey the repository

Build a mental model by reading files in this order. Stop expanding into a folder once its purpose is clear —
exhaustive reads are wasteful.

0. **Knowledge graph (if available)**: if `graphify` MCP tools are present, query the graph first for a fast
   architectural overview — it compresses the relationship-heavy parts of exploration into a few tool calls.
   Run `graphify_graph_stats` to confirm the graph is populated, then `graphify_god_nodes` to surface the core
   abstractions, and `graphify_query_graph` for any concept-level question (e.g. "entry points", "data stores",
   "auth"). Treat graph output as a hypothesis layer — still verify against the codebase. If `graphify` is
   unavailable or the graph is empty/stale, skip and proceed with file-based survey. See `telamon.graphify`.
1. **Top-level orientation**: `README.md`, `AGENTS.md`, `CLAUDE.md`, `Makefile`, `package.json` / `composer.json` /
   `pyproject.toml` / `Cargo.toml`, `.gitignore`, `docker-compose.yml`, `.env.dist`.
2. **Directory shape**: list the root and one level deep. Identify which folders hold source, tests, config,
   scripts, docs, vendored code, runtime data.
3. **Entry points**: scripts in `bin/`, `scripts/`, `cmd/`, framework bootstraps (`public/index.php`,
   `src/main.ts`, `manage.py`, `main.go`, …).
4. **Architecture artefacts**: `docs/architecture*.md`, ADRs (`docs/adr/`, `.ai/adr/`), `.ai/telamon/memory/brain/ADRs.md`,
   `.ai/telamon/memory/brain/PDRs.md`.
5. **Source tree**: sample one or two representative files per major component to confirm patterns (layering,
   naming, framework usage). Use `repomix` or `codebase-peek` to bulk-scan when many files belong to the same
   concern — see `telamon.search_code` for tool selection.
6. **Tests**: locate the test root, identify the framework, note the layering convention (unit/integration/e2e).
7. **CI/CD and tooling**: `.github/workflows/`, `.gitlab-ci.yml`, `Dockerfile*`, `Makefile` targets, lint/format config.

Prefer broad coverage over depth. If a folder is gitignored or marked `no-vcs`, skip it (see `ignore.md`).

**The `.ai/` directory**: this folder holds agent-only artefacts (memory vault, planning issue folders,
thinking/scratch, project rules). It is **gitignored by convention** — nothing under `.ai/` is committed to
the project repository. Treat it as local working state for agents, not as project source. When writing the
description, mention `.ai/` under *Repository layout* (one row, noting "agent working state, gitignored")
and under *Critical conventions* (the rule that `.ai/` contents are never committed). Do not enumerate its
sub-structure — that belongs to `telamon.memory_management`.

### Step 3: Identify what may be problematic

While exploring, capture observations under these categories. **Be specific** — cite paths. **Be brief** —
one line each. Do not fix anything; this is reconnaissance.

- **Inconsistencies**: two patterns for the same concern (e.g. two HTTP clients, two test styles, mixed naming).
- **Architectural drift**: dependencies flowing the wrong way, framework code in domain layers, god modules.
- **Stale or orphaned**: directories with no recent commits, dead config, TODO/FIXME clusters.
- **Risky areas**: missing tests, weak types, security-sensitive code without review, manual deploy steps.
- **Convention gaps**: behaviour exists but is undocumented, or docs disagree with code.

If a category has no findings, omit it. Do not pad.

### Step 4: Write the description

Write the result to `.ai/telamon/memory/project-rules/description.md`, overwriting the previous content. After writing, run `format-md` on the file to align table columns.

Follow the template below. Adjust section titles to fit the project, but keep the section order: *purpose →
layout → architecture → lifecycle/workflows → conventions → rough edges → pointers*. This order is what an
agent needs in roughly the order it needs it.

Constraints on the output:

- **Length**: target 80–150 lines. Hard cap 200. Density over completeness.
- **Voice**: technical, declarative, present tense. No marketing adjectives. No hedging.
- **Tables for layouts**: directory tables, file/role tables. Tables compress better than prose.
- **Cite paths**: every architectural claim points at a file or folder.
- **No procedures**: do not document *how* to install/build/test in detail — link to the canonical doc instead.
- **Flag, do not solve**: the *Rough edges* section names problems without prescribing fixes.

### Step 5: Optimize for agent consumption

The deliverable is loaded into every future agent session — token cost compounds. Run two passes:

1. **Structure pass** — load `telamon.optimize-instructions` and apply its writing-rules checklist (economy,
   precision, non-redundant, scoped) to the description. Drop hedging, collapse prose into tables where
   possible, remove anything an agent cannot act on.
2. **Compression pass** — load `caveman` (full intensity) and rewrite the description in caveman style.
   Preserve all paths, identifiers, and technical claims verbatim; compress only the connective tissue.
   The output remains valid Markdown; only the prose voice changes.

### Step 6: Verify and report

1. Re-read the written file. Confirm every architectural claim maps to a real path and no path was mangled
   by the compression pass.
2. Run `wc -l` on the file. If over 200 lines, compress further before reporting.
3. Report to the caller using the `telamon.agent-communication` `FINISHED` signal. Include: file path,
   line count, and a 3-bullet recap (what the project *is*, its dominant architectural pattern, top rough edge).

If exploration cannot proceed (repo unreadable, no source detected, write target inaccessible), follow
`telamon.exception-handling` and emit `BLOCKED` with the specific cause and what is needed to unblock.

## Template

> ---
> tags: [project-rules, description, bootstrap]
> description: What \<Project\> is, how the repo is laid out, key conventions and rough edges
> ---
>
> ## What this project is
>
> One paragraph: what the project does, who it is for, what makes it distinctive. Name the primary
> language(s), runtime, and any framework that shapes the whole repo.
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
> Describe the dominant pattern (layered, hexagonal, MVC, modular monolith, microservices, …) and the actual
> module/component boundaries. Note the direction of dependencies. If the project follows a documented
> pattern (e.g. DDD + Hexagonal), name it and point at the canonical doc.
>
> Sub-bullets for: entry points, data stores, external services, key cross-cutting concerns (auth, logging,
> messaging).
>
> ## Lifecycle & workflows
>
> _(Optional — include only if the project has non-obvious lifecycles like install/init/update, multi-stage
> deploy, or release pipelines worth knowing up front.)_
>
> Brief, numbered. Link to the canonical doc rather than reproducing it.
>
> ## Critical conventions
>
> Bullet list. Each bullet is one rule a contributor must know that is not obvious from the code. Examples:
> dist vs runtime config files, gitignore patterns, symlinked paths, files-not-to-read, naming rules.
>
> ## Rough edges
>
> _(Omit if none found.)_
>
> Brief, factual. One bullet per observation. Examples:
>
> - Two test styles coexist: `tests/unit/` uses Pest, `tests/Feature/` uses PHPUnit.
> - `src/legacy/` has no tests and is referenced by `src/api/v1/`.
> - `docs/architecture.md` describes a v1 layout; code has since moved to v2 (see `src/v2/`).
>
> Do not propose fixes here.
>
> ## When to read the docs vs the code
>
> Pointers table: for question type → go to file/folder. Helps future agents skip exploration.

## Tools

Prefer these tools for efficient exploration:

- `graphify` — query the codebase knowledge graph for architecture, core abstractions, and concept paths.
  Use first when available; see `telamon.graphify`.
- `repomix` — bulk-pack a folder when you need broad context across many files in one area.
- `codebase-index` (`codebase_peek`, `codebase_search`) — locate concepts and definitions semantically.
- `glob` / `grep` — exact filename and pattern lookup.
- `ast-grep` — structural code search when prose grep is ambiguous.

See `telamon.search_code` for choosing between them.

## MUST

- Write the final description to `.ai/telamon/memory/project-rules/description.md` and nowhere else.
- Overwrite the existing file in place — this is the canonical project map.
- Cite real paths for every architectural claim; verify each path exists before writing.
- Run the `telamon.optimize-instructions` pass before the compression pass — order matters; compressing
  unstructured prose loses information.
- Run the `caveman` compression pass on the final document; paths and identifiers stay verbatim.
- Keep the file at or under 200 lines; aim for 80–150 *after* compression.
- End with a `FINISHED` signal containing file path, line count, and the 3-bullet recap.

## MUST NOT

- Write to any other location, or create supporting files in `project-rules/`.
- Include install/build/test step-by-step instructions — link to the canonical doc.
- Recommend fixes in the *Rough edges* section; flag only.
- Read or describe files marked `no-vcs` or excluded by `ignore.md`.
- Pad with marketing language, aspirations, or generic best-practice advice.

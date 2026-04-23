---
layout: page
title: Repository Layout
description: Full directory structure explained.
nav_section: docs
---

## Top-level structure

| Directory | Purpose |
|---|---|
| `bin/` | Entry-point scripts (install, init, doctor, status, update, telamon CLI) |
| `src/` | All source: agents, commands, plugins, skills, installer modules |
| `storage/` | Runtime data — git-ignored except `opencode.jsonc` |
| `docs/` | Documentation (this site) |
| `test/` | Test suite and agent evaluations |
| `scripts/` | Utility scripts |

---

## Full directory tree

```
bin/
  init.sh                    # project initialiser (brain scaffold + symlinks + plugins)
  install.sh                 # orchestrator: --pre-docker, --post-docker phases
  update.sh                  # upgrades all Telamon-managed tools to latest versions
  doctor.sh                  # comprehensive health check (connectivity, config, secrets)
  status.sh                  # quick installation status of all Telamon tools
  telamon                    # global CLI dispatch script (symlink target)

src/
  AGENTS.md                  # main agent instructions file (symlinked into each project)
  agents/                    # agent role definitions (one .md per role)
    telamon.md               # orchestrator — classifies, delegates, leads workflows
    architect.md             # software architect — designs plans and ADRs
    critic.md                # critic — audits codebase, reviews plans
    developer.md             # developer — implements plans into production code
    po.md                    # product owner — domain expert, backlog grooming
    reviewer.md              # reviewer — reviews changesets against plan + conventions
    security.md              # security engineer — threat models, vulnerability assessment
    tester.md                # tester — validates implementations, writes tests
    ui-designer.md           # UI designer — visual specs, design tokens
    ux-designer.md           # UX designer — user flows, interaction specs
  commands/                  # slash commands (one .md per command)
  plugins/                   # OpenCode plugins
    graphify.js              # injects graph context into first tool call
    rtk.ts                   # RTK token compression integration
    rtk-dedupe.ts            # deduplicates RTK output
    session-capture.js       # auto-captures learnings before compaction
    diff-context.js          # injects git change summary on first bash call
  docker/
    initdb/                  # Postgres init scripts (run on first container start)
  skills/
    memory/                  # memory & context management skills
    dev/                     # development convention skills
    workflow/                # workflow orchestration skills
    addyosmani/              # general engineering skills (from addyosmani/agent-skills)
  install/
    functions/               # shared bash library (colors, stdout, state, os, opencode, secrets)
    homebrew/                # Homebrew installer
    docker/                  # Docker installer
    python/                  # Python (uv) installer
    nodejs/                  # Node.js installer
    ogham/                   # Ogham binary + config + FlashRank reranking
    graphify/                # Graphify binary + MCP wrapper + scheduled updates + plugin
    graphiti/                # Graphiti + Neo4j setup (optional, profile-gated)
    langfuse/                # Langfuse observability stack (optional, profile-gated)
    caveman/                 # Caveman skill download
    qmd/                     # QMD binary + skill download + vault collection init
    rtk/                     # RTK binary + opencode plugin wiring
    opencode/                # opencode binary + shared opencode.jsonc template
    codebase-index/          # MCP registration + per-project config
    obsidian/                # Obsidian binary install + MCP registration
    repomix/                 # Repomix MCP installer, init, update, doctor
    promptfoo/               # promptfoo eval framework installer, init, update
    session-capture/         # session-capture opencode plugin + init
    diff-context/            # diff-context opencode plugin registration
    cli/                     # telamon CLI + desktop menu entry installer
    shell/                   # shell profile PATH additions

test/
  test-init.sh               # assertions for make init wiring
  eval/                      # agent evaluation suite (promptfoo)
    promptfooconfig.yaml     # root eval config
    evals/                   # per-eval YAML configs
    fixtures/                # test inputs per eval

storage/                     # runtime data — git-ignored except opencode.jsonc
  opencode.jsonc             # shared opencode config (tracked); projects symlink to this
  secrets/                   # one plain-text file per secret (git-ignored)
  state/                     # installer state (saved inputs, completed steps)
  pgdata/                    # Postgres data volume
  ollama/                    # Ollama model cache
  graphify/                  # Graphify output cache
  qmd/                       # QMD index and cache
  obsidian/<project-name>/   # per-project Obsidian vault
```

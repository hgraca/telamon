# Repository Layout

```
bin/
  init.sh                    # project initialiser (brain scaffold + symlinks + plugins)
  install.sh                 # orchestrator: --pre-docker, --post-docker phases
  update.sh                  # upgrades all Telamon-managed tools to latest versions
  doctor.sh                  # comprehensive health check (connectivity, config, secrets)
  status.sh                  # quick installation status of all Telamon tools

src/
  context/                   # agent instruction docs (loaded into every project)
    ogham.md                 # how to use Ogham
    graphify.md              # how to use Graphify
    cass.md                  # how to use cass
    obsidian.md              # how to use the Obsidian vault
    codebase-index.md        # how to use the codebase index
  skills/
    memory/
      memory-stack/SKILL.md  # session-start memory bootstrap skill
      session-capture/SKILL.md  # pre-compaction + wrap-up memory capture skill
      cass/SKILL.md          # cass usage skill (downloaded from upstream on install/update)
      qmd/SKILL.md           # QMD vault semantic search skill (downloaded or bundled)
      graphify/SKILL.md      # codebase knowledge graph skill
      obsidian-vault/        # vault skill + vault scaffold template
        SKILL.md
        _tmpl/               # full vault template (copied per project on make init)
          bootstrap/         # always-on context files (loaded like AGENTS.md)
          brain/             # memories, key_decisions, patterns, gotchas
          work/active|archive|incidents/
          reference/
          thinking/
    dev/                     # agentic workflow skills
      agent-communication/   # inter-agent communication protocol
      caveman/SKILL.md       # token-efficient communication mode (downloaded from upstream)
      changeset-review/      # code review against a plan
      codebase-audit/        # holistic codebase health review
      create-adr/            # architecture decision records
      create-use-case/       # CQRS command/handler generation
      evaluation/            # post-iteration quality assessment
      exception-handling/    # structured error recovery for agent failures
      implementation-planning/
      memory-management/
      optimize-instructions/
      plan-execution/
      plan-review/
      plan-summary/
      test-reporting/
      ui-specification/
      ux-design/
      workflow.implement-story/
      workflow.plan-story/
    addyosmani/              # general engineering skills (from addyosmani/agent-skills)
      api-and-interface-design/
      browser-testing-with-devtools/
      ci-cd-and-automation/
      code-review-and-quality/
      code-simplification/
      debugging-and-error-recovery/
      frontend-ui-engineering/
      git-workflow-and-versioning/
      incremental-implementation/
      performance-optimization/
      planning-and-task-breakdown/
      security-and-hardening/
      shipping-and-launch/
      spec-driven-development/
      test-driven-development/
      ... (and more)
  install/
    functions/               # shared bash library (colors, stdout, state, os, apt, opencode)
    homebrew/install.sh
    docker/install.sh
    python/install.sh        # installs uv
    nodejs/install.sh
    ogham/                   # ogham binary + config + FlashRank reranking
    graphify/                # graphify binary + per-project git hook + opencode plugin
    cass/                    # cass binary + skill download + init.sh (post-commit hook)
    caveman/                 # caveman skill download (no binary)
    qmd/                     # qmd binary install + skill download + init.sh (vault collections)
    rtk/                     # RTK binary + opencode plugin wiring
    opencode/                # opencode binary + shared storage/opencode.jsonc template
    codebase-index/          # MCP registration + per-project codebase-index.json
    obsidian/                # Obsidian binary install + MCP registration
    session-capture/         # session-capture opencode plugin + init.sh
    shell/write-env.sh       # shell profile PATH additions

storage/                     # runtime data — git-ignored except opencode.jsonc
  opencode.jsonc             # shared opencode config (tracked); projects symlink to this
  secrets/                   # one plain-text file per secret (git-ignored)
  state/                     # installer state (saved inputs, completed steps)
  pgdata/                    # Postgres data volume (git-ignored)
  ollama/                    # Ollama model cache (git-ignored)
  graphify/                  # graphify output cache (git-ignored)
  obsidian/<project-name>/   # per-project Obsidian vault
    bootstrap/               # always-on context (loaded like AGENTS.md)
    brain/                   # memories, key_decisions, patterns, gotchas
    work/active/             # in-progress work notes
    work/archive/            # completed work notes
    work/incidents/          # incident docs
    reference/               # architecture maps, flow docs
    thinking/                # scratchpad for drafts

docker-compose.yml           # postgres, ollama, ollama-init
.env.dist                    # template for .env (POSTGRES_PASSWORD, OBSIDIAN_API_KEY)
Makefile                     # up, down, purge, restart, status, doctor, update, init, test
```

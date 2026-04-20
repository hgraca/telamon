# Repository Layout

```
bin/
  init.sh                    # project initialiser (brain scaffold + symlinks + plugins)
  install.sh                 # orchestrator: --pre-docker, --post-docker phases
  update.sh                  # upgrades all Telamon-managed tools to latest versions
  doctor.sh                  # comprehensive health check (connectivity, config, secrets)
  status.sh                  # quick installation status of all Telamon tools

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
    archive.md               # /archive — archive completed work
    caveman.md               # /caveman — toggle token-efficient communication
    dev.md                   # /dev — delegate a code task to the developer
    epic.md                  # /epic — break an epic into stories and implement
    eval.md                  # /eval — run agent evaluations
    gh_review.md             # /gh_review — review a GitHub pull request
    implement.md             # /implement — implement an approved plan
    plan.md                  # /plan — plan a story or feature
    review.md                # /review — review a code changeset
    story.md                 # /story — plan and implement a story end-to-end
    test.md                  # /test — write or run tests
    vault-audit.md           # /vault-audit — audit the knowledge vault
  plugins/                   # OpenCode plugins
    graphify.js              # injects graph context into first tool call
    rtk.ts                   # RTK token compression integration
    rtk-dedupe.ts            # deduplicates RTK output
    session-capture.js       # auto-captures learnings before compaction
  docker/
    initdb/                  # Postgres init scripts (run on first container start)
  context/                   # (reserved for future use)
  skills/
    memory/
      memory-management/     # vault structure, routing, retrieval, writing, quality rules
        SKILL.md
        _tmpl/               # full vault template (copied per project on make init)
          bootstrap/         # always-on context files (loaded like AGENTS.md)
          brain/             # memories, key_decisions, patterns, gotchas
          work/active|archive|incidents/
          reference/
          thinking/
      recall-memories/SKILL.md           # session-start memory bootstrap
      thinking/SKILL.md                  # scratch files, drafts, WIP content management
      remember-lessons-learned/SKILL.md  # continuous capture during work
      remember-task/SKILL.md             # post-task lesson capture
      remember-checkpoint/SKILL.md       # pre-compaction state preservation
      remember-session/SKILL.md          # end-of-session wrap-up
      _tools/
        qmd/SKILL.md         # QMD vault semantic search (init, query, index maintenance)
        ogham/SKILL.md       # Ogham semantic agent memory (profile switching, storing, searching)
        obsidian/SKILL.md    # Obsidian MCP vault interaction
        cass/SKILL.md        # cass session history search (downloaded from upstream on install/update)
        graphify/SKILL.md    # codebase knowledge graph (downloaded from upstream on install/update)
        repomix/SKILL.md     # repomix directory context packer (agent usage guidance)
    dev/                     # development convention skills
      api/
        rest-conventions/    # RESTful API conventions (URL structure, errors, pagination)
      architecture/
        architecture-rules/  # universal architecture rules (priorities, security, forbidden patterns)
        explicit-architecture/  # DDD + Hexagonal + CQRS layer structure and dependency rules
      create-adr/            # architecture decision records
      create-use-case/       # CQRS command/handler generation
      documentation-rules/   # repository documentation conventions
      git-rules/             # git commit conventions (gitignored paths, conventional commits)
      makefile/              # Makefile lifecycle commands
      php/
        laravel/             # Laravel conventions
        message-bus/         # PHP message bus integration
        php-rules/           # PHP coding rules (strict typing, enums, PHPDoc)
      testing/               # test commands, strategy, conventions
        promptfoo/           # agent evaluation with promptfoo (nested skill)
    workflow/                # workflow orchestration skills
      agent-communication/   # inter-agent communication protocol
      audit_codebase/        # holistic codebase health review
      caveman/SKILL.md       # token-efficient communication mode (downloaded from upstream)
      epic/                  # breaks an epic into stories, plans and implements each
      exception-handling/    # structured error recovery for agent failures
      execute_plan/          # executes implementation plan steps systematically
      implement_story/       # implements an approved plan (tester -> developer -> reviewer cycle)
      optimize-instructions/ # agent instruction file optimization
      plan_implementation/   # creates implementation plans from a brief
      plan_story/            # plans a user story (backlog + architecture spec)
      retrospective/         # post-iteration quality assessment
      review_changeset/      # code review against a plan
      review_plan/           # reviews an architect's plan
      review_security/       # PHP security review (STRIDE, OWASP, vulnerability checklist)
      summarize_plan/        # produces planning summary after a planning stage
      test_codebase/         # test result documentation
      ui-specification/      # implementation-ready UI specifications
      ux-design/             # UX specifications and validation
    addyosmani/              # general engineering skills (from addyosmani/agent-skills)
      api-and-interface-design/
      browser-testing-with-devtools/
      ci-cd-and-automation/
      code-review-and-quality/
      code-simplification/
      context-engineering/
      debugging-and-error-recovery/
      deprecation-and-migration/
      documentation-and-adrs/
      frontend-ui-engineering/
      git-workflow-and-versioning/
      idea-refine/
      incremental-implementation/
      performance-optimization/
      planning-and-task-breakdown/
      security-and-hardening/
      shipping-and-launch/
      source-driven-development/
      spec-driven-development/
      test-driven-development/
      using-agent-skills/
  install/
    functions/               # shared bash library (colors, stdout, state, os, apt, opencode, secrets, env)
    homebrew/install.sh
    docker/install.sh
    python/install.sh        # installs uv
    nodejs/install.sh
    ogham/                   # ogham binary + config + FlashRank reranking
    graphify/                # graphify binary + MCP wrapper + scheduled updates + opencode plugin
    graphiti/                # graphiti + Neo4j setup (optional, profile-gated)
    langfuse/                # Langfuse observability stack setup (optional, profile-gated)
    cass/                    # cass binary + skill download + scheduled index updates
    caveman/                 # caveman skill download (no binary)
    qmd/                     # qmd binary install + skill download + init.sh (vault collections)
    rtk/                     # RTK binary + opencode plugin wiring
    opencode/                # opencode binary + shared storage/opencode.jsonc template
    codebase-index/          # MCP registration + per-project codebase-index.json
    obsidian/                # Obsidian binary install + MCP registration
    repomix/                 # Repomix MCP installer, init, update, doctor scripts
    promptfoo/               # promptfoo eval framework installer, init, update scripts
    session-capture/         # session-capture opencode plugin + init.sh
    shell/write-env.sh       # shell profile PATH additions

scripts/
  is-in-docker.sh            # helper: detects if running inside a Docker container

test/
  test-init.sh               # assertions for make init wiring
  eval/                      # agent evaluation suite (promptfoo)
    promptfooconfig.yaml     # root eval config (opencode:sdk provider)
    package.json             # @opencode-ai/sdk dependency
    evals/                   # per-eval YAML configs
      request-classification.yaml
      plan-structure.yaml
      code-review-quality.yaml
    fixtures/                # test inputs per eval (story briefs, seeded-bug PHP code)

storage/                     # runtime data — git-ignored except opencode.jsonc
  opencode.jsonc             # shared opencode config (tracked); projects symlink to this
  secrets/                   # one plain-text file per secret (git-ignored)
    ogham-database-url       # Postgres connection string for Ogham
    obsidian-api-key         # Obsidian Local REST API key
    graphify-python          # absolute path to graphify's Python interpreter
    telamon-root             # absolute path to the Telamon root directory
    gh_pat                   # GitHub personal access token
    qmd-cache-home           # XDG_CACHE_HOME override for QMD
  state/                     # installer state (saved inputs, completed steps)
  pgdata/                    # Postgres data volume (git-ignored)
  ollama/                    # Ollama model cache (git-ignored)
  graphify/                  # graphify output cache (git-ignored)
  qmd/                       # QMD index and cache (git-ignored)
  obsidian/<project-name>/   # per-project Obsidian vault
    bootstrap/               # always-on context (loaded like AGENTS.md)
    brain/                   # memories, key_decisions, patterns, gotchas
    work/active/             # in-progress work notes
    work/archive/            # completed work notes
    work/incidents/          # incident docs
    reference/               # architecture maps, flow docs
    thinking/                # scratchpad for drafts
  langfuse-pgdata/           # Langfuse Postgres data (git-ignored, optional)
  langfuse-clickhouse/       # Langfuse ClickHouse data (git-ignored, optional)
  neo4j-data/                # Neo4j data (git-ignored, optional)

graphify-out/                # Graphify output for the Telamon project itself
docker-compose.yml           # postgres, ollama, ollama-init + optional: langfuse, graphiti
opencode.jsonc               # root opencode config for working on Telamon itself
repomix.config.json          # per-project Repomix config (project root, created by init.sh)
.env.dist                    # template for .env (passwords, API keys, optional service flags)
Makefile                     # up, down, purge, restart, status, doctor, update, init, test
```

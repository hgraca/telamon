---
layout: page
title: Skills Library
description: Structured instruction sets that guide agents through specific tasks.
nav_section: docs
---

Skills are structured instruction sets loaded automatically based on context. Skill source code: [`src/skills/`](https://github.com/hgraca/telamon/tree/main/src/skills).

## Development conventions

| Skill                                                                                                                           | Description                                                   |
|---------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| [architecture-rules](https://github.com/hgraca/telamon/blob/main/src/skills/dev/architecture/architecture-rules/SKILL.md)       | Priority order, security, forbidden patterns, design defaults |
| [explicit-architecture](https://github.com/hgraca/telamon/blob/main/src/skills/dev/architecture/explicit-architecture/SKILL.md) | DDD + Hexagonal + CQRS layers, component boundaries           |
| [rest-conventions](https://github.com/hgraca/telamon/blob/main/src/skills/dev/api/rest-conventions/SKILL.md)                    | RESTful API URL structure, methods, envelopes, errors         |
| [create-adr](https://github.com/hgraca/telamon/blob/main/src/skills/dev/create-adr/SKILL.md)                                    | Creates Architecture Decision Records                         |
| [create-use-case](https://github.com/hgraca/telamon/blob/main/src/skills/dev/create-use-case/SKILL.md)                          | Generates CQRS Command/CommandHandler pairs with tests        |
| [documentation-rules](https://github.com/hgraca/telamon/blob/main/src/skills/dev/documentation-rules/SKILL.md)                  | File organization, README TOC, docs/ structure                |
| [gh-review](https://github.com/hgraca/telamon/blob/main/src/skills/dev/gh-review/SKILL.md)                                      | Addresses code review comments on a GitHub PR                 |
| [git-rules](https://github.com/hgraca/telamon/blob/main/src/skills/dev/git-rules/SKILL.md)                                      | Gitignored paths, ticket ID prefixes, conventional commits    |
| [makefile](https://github.com/hgraca/telamon/blob/main/src/skills/dev/makefile/SKILL.md)                                        | CLI commands inside containers, dev environment lifecycle     |
| [testing](https://github.com/hgraca/telamon/blob/main/src/skills/dev/testing/SKILL.md)                                          | Test strategy, conventions, naming, locations by layer        |
| [testing/promptfoo](https://github.com/hgraca/telamon/blob/main/src/skills/dev/testing/promptfoo/SKILL.md)                      | Agent evaluation: running evals, writing assertions           |
| [php-rules](https://github.com/hgraca/telamon/blob/main/src/skills/dev/php/php-rules/SKILL.md)                                  | Strict typing, constructor promotion, PHPDoc                  |
| [phpunit](https://github.com/hgraca/telamon/blob/main/src/skills/dev/php/phpunit/SKILL.md)                                      | PHPUnit conventions, test attributes, handler cleanup         |
| [laravel](https://github.com/hgraca/telamon/blob/main/src/skills/dev/php/laravel/SKILL.md)                                      | Laravel 10 conventions, Eloquent, controllers                 |
| [message-bus](https://github.com/hgraca/telamon/blob/main/src/skills/dev/php/message-bus/SKILL.md)                              | PHP message bus, dispatching commands/events/queries          |

## Workflow (Telamon only)

| Skill                                                                                                               | Description                                               |
|---------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| [agent-communication](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/agent-communication/SKILL.md) | Inter-agent delegation protocol and status signals        |
| [plan-story](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/plan_story/SKILL.md)                   | Plans a story: backlog + architecture + optional UX/UI    |
| [implement-story](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/implement_story/SKILL.md)         | Implements plan via Tester -> Developer -> Reviewer cycle |
| [epic](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/epic/SKILL.md)                               | Breaks epics into stories, plans and implements each      |
| [plan-implementation](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/plan_implementation/SKILL.md) | Creates implementation plans across all layers            |
| [execute-plan](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/execute_plan/SKILL.md)               | Executes plan steps systematically                        |
| [review-plan](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/review_plan/SKILL.md)                 | Reviews architect's plan for correctness                  |
| [review-changeset](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/review_changeset/SKILL.md)       | Reviews code against plan and conventions                 |
| [review-security](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/review_security/SKILL.md)         | STRIDE, OWASP Top 10, PHP vulnerability checklist         |
| [audit-codebase](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/audit_codebase/SKILL.md)           | Audits for pattern drift and architectural erosion        |
| [test-codebase](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/test_codebase/SKILL.md)             | Test reports: results, bugs, coverage assessment          |
| [summarize-plan](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/summarize_plan/SKILL.md)           | Planning summary report after planning completes          |
| [exception-handling](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/exception-handling/SKILL.md)   | Error taxonomy and recovery for agent failures            |
| [caveman](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/caveman/SKILL.md)                         | Ultra-compressed communication mode                       |
| [ui-specification](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/ui-specification/SKILL.md)       | Implementation-ready UI specs with design tokens          |
| [ux-design](https://github.com/hgraca/telamon/blob/main/src/skills/workflow/ux-design/SKILL.md)                     | UX specs: user flows, interactions, states                |

## Memory & context

| Skill                                                                                                                       | Description                                           |
|-----------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| [recall-memories](https://github.com/hgraca/telamon/blob/main/src/skills/memory/recall-memories/SKILL.md)                   | Recall context at session start                       |
| [remember-lessons-learned](https://github.com/hgraca/telamon/blob/main/src/skills/memory/remember-lessons-learned/SKILL.md) | Save decisions, patterns, bugs as they arise          |
| [remember-task](https://github.com/hgraca/telamon/blob/main/src/skills/memory/remember-task/SKILL.md)                       | Record learnings after completing a task              |
| [remember-checkpoint](https://github.com/hgraca/telamon/blob/main/src/skills/memory/remember-checkpoint/SKILL.md)           | Save state before context overflow                    |
| [remember-session](https://github.com/hgraca/telamon/blob/main/src/skills/memory/remember-session/SKILL.md)                 | Capture everything when a session ends                |
| [memory-management](https://github.com/hgraca/telamon/blob/main/src/skills/memory/memory-management/SKILL.md)               | Vault folder structure, routing, writing constraints  |
| [thinking](https://github.com/hgraca/telamon/blob/main/src/skills/memory/thinking/SKILL.md)                                 | Scratch files, drafts, WIP content management         |
| [obsidian](https://github.com/hgraca/telamon/blob/main/src/skills/memory/_tools/obsidian/SKILL.md)                          | Obsidian MCP: searching, reading, writing vault notes |
| [qmd](https://github.com/hgraca/telamon/blob/main/src/skills/memory/_tools/qmd/SKILL.md)                                    | QMD: search markdown knowledge bases                  |
| [graphify](https://github.com/hgraca/telamon/blob/main/src/skills/memory/_tools/graphify/SKILL.md)                          | Graphify: build, query, maintain knowledge graph      |
| [repomix](https://github.com/hgraca/telamon/blob/main/src/skills/memory/_tools/repomix/SKILL.md)                            | Repomix: pack directories for LLM consumption         |

## Self-improvement

| Skill                                                                                                                           | Description                                             |
|---------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| [retrospective](https://github.com/hgraca/telamon/blob/main/src/skills/self-improvement/retrospective/SKILL.md)                 | Post-iteration quality evaluation and metrics           |
| [address-retro](https://github.com/hgraca/telamon/blob/main/src/skills/self-improvement/address_retro/SKILL.md)                 | Implements improvements from retrospective findings     |
| [improve-reviewer](https://github.com/hgraca/telamon/blob/main/src/skills/self-improvement/improve-reviewer/SKILL.md)           | Improves reviewer to catch issues from external reviews |
| [optimize-instructions](https://github.com/hgraca/telamon/blob/main/src/skills/self-improvement/optimize-instructions/SKILL.md) | Optimizes agent instruction files for clarity           |

## Third-party skills

### Addy Osmani agent skills

[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) — installed into `.opencode/skills/telamon/addyosmani/`.

| Skill                         | Description                                                |
|-------------------------------|------------------------------------------------------------|
| api-and-interface-design      | Guides stable API and interface design                     |
| browser-testing-with-devtools | Tests in real browsers via Chrome DevTools MCP             |
| ci-cd-and-automation          | Automates CI/CD pipeline setup                             |
| code-review-and-quality       | Conducts multi-axis code review                            |
| code-simplification           | Simplifies code for clarity without changing behavior      |
| context-engineering           | Optimizes agent context setup and rules files              |
| debugging-and-error-recovery  | Guides systematic root-cause debugging                     |
| deprecation-and-migration     | Manages deprecation and migration paths                    |
| documentation-and-adrs        | Records architectural decisions and documentation          |
| frontend-ui-engineering       | Builds production-quality UIs                              |
| git-workflow-and-versioning   | Structures git workflow practices                          |
| idea-refine                   | Refines ideas through divergent and convergent thinking    |
| incremental-implementation    | Delivers changes incrementally across multiple files       |
| performance-optimization      | Optimizes application performance and Core Web Vitals      |
| planning-and-task-breakdown   | Breaks work into ordered, implementable tasks              |
| security-and-hardening        | Hardens code against vulnerabilities and untrusted input   |
| shipping-and-launch           | Prepares production launches with checklists and rollbacks |
| source-driven-development     | Grounds decisions in official documentation                |
| spec-driven-development       | Creates specifications before coding                       |
| test-driven-development       | Drives development with tests                              |
| using-agent-skills            | Discovers and invokes other skills (meta-skill)            |

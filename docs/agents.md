---
layout: page
title: Multi-Agent System
description: Telamon's agent architecture — primary agents, sub-agents, and roles.
nav_section: docs
---

Telamon ships two primary agents. Pick the one that matches how you want to work.

## Primary agents

| Agent         | Model         | Style                                                   | When to use                                       |
|---------------|---------------|---------------------------------------------------------|---------------------------------------------------|
| **Telamon**   | Claude Opus   | Autonomous — classifies, plans, delegates, implements   | Stories, epics, multi-step tasks, end-to-end work |
| **Companion** | Claude Sonnet | Collaborative — asks before acting, works incrementally | Exploratory work, debugging, design discussions   |

**Telamon** receives every request, classifies it by type and size, and either handles it directly or delegates to one of 10 specialized sub-agents. It leads planning and implementation workflows end-to-end and manages the knowledge vault.

**Companion** never delegates and never runs autonomous workflows. It works *with* you — one function, one test, one change at a time.

## Sub-agents

| Sub-agent                                                                            | Role                                               | Permissions          |
|--------------------------------------------------------------------------------------|----------------------------------------------------|----------------------|
| [architect](https://github.com/hgraca/telamon/blob/main/src/agents/architect.md)     | Designs technical plans and ADRs                   | Read-only            |
| [developer](https://github.com/hgraca/telamon/blob/main/src/agents/developer.md)     | Implements plans into production code              | Full file + shell    |
| [tester](https://github.com/hgraca/telamon/blob/main/src/agents/tester.md)           | Writes and runs tests, validates implementations   | Shell (tests) + file |
| [reviewer](https://github.com/hgraca/telamon/blob/main/src/agents/reviewer.md)       | Reviews changesets against plan and conventions    | Read-only + tests    |
| [critic](https://github.com/hgraca/telamon/blob/main/src/agents/critic.md)           | Audits codebase for inconsistencies and drift      | Read-only            |
| [po](https://github.com/hgraca/telamon/blob/main/src/agents/po.md)                   | Domain expert, backlog grooming, requirements      | Read-only            |
| [security](https://github.com/hgraca/telamon/blob/main/src/agents/security.md)       | Security audits, threat modelling, vulnerabilities | Read-only + audit    |
| [ui-designer](https://github.com/hgraca/telamon/blob/main/src/agents/ui-designer.md) | Visual specs, design tokens, screen layouts        | Read-only            |
| [ux-designer](https://github.com/hgraca/telamon/blob/main/src/agents/ux-designer.md) | User flows, interaction specs, state definitions   | Read-only            |

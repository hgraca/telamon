---
layout: page
title: promptfoo
description: Automated quality checks for agent behavior.
nav_section: docs
---

[promptfoo](https://github.com/promptfoo/promptfoo) — Agent Evaluation Framework

Automated quality checks for agent behavior. Tests request classification, plan structure, code review quality, and skill activation.

- Declarative YAML configs with prompts, test cases, and assertions
- `opencode:sdk` provider starts an ephemeral opencode server per eval
- Web UI: `npx -y promptfoo view`

**Commands:**

```bash
cd tests/agents && npx -y promptfoo eval
npx -y promptfoo view
```

**Slash command:** `/eval`

**Priority:** Tier 2

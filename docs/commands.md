---
layout: page
title: Slash Commands
description: All slash commands available in Telamon.
nav_section: docs
---

Slash commands trigger specific workflows. Type them in the opencode chat.

| Command                 | Description                                                      |
|-------------------------|------------------------------------------------------------------|
| `/story <brief>`        | Plan and implement a story end-to-end                            |
| `/epic <brief>`         | Break an epic into stories, plan and implement each              |
| `/plan <brief>`         | Plan a story or feature (backlog + architecture)                 |
| `/implement <brief>`    | Implement an approved plan                                       |
| `/dev <task>`           | Delegate a code task directly to the developer                   |
| `/test`                 | Write or run tests for the current changeset                     |
| `/review`               | Review the current code changeset                                |
| `/gh_review <PR#>`      | Address review comments on a GitHub PR                           |
| `/eval`                 | Run agent evaluations with promptfoo                             |
| `/caveman [level]`      | Toggle token-efficient communication (`lite` / `full` / `ultra`) |
| `/archive <note>`       | Archive a completed work note                                    |
| `/vault-audit`          | Deep structural audit of the knowledge vault                     |
| `/address-retro <path>` | Implement improvements from a retrospective                      |
| `/format-md <path>`     | Align markdown tables in a file or directory                     |
| `/script <path>`        | Run a shell script and pass output to the LLM                    |

Command definitions live in [`src/commands/`](https://github.com/hgraca/telamon/tree/main/src/commands).

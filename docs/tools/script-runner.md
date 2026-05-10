---
layout: page
title: Script Runner (Retired)
description: OpenCode plugin that ran shell scripts via the /script command — retired in favour of thin /command wrappers around scripts.
nav_section: docs
---

# Script Runner (Retired)

An OpenCode plugin that intercepted `/script <path> [args...]` commands, resolved the path relative to the project root, ran the script via bash, and returned stdout, stderr, and the exit code back to the LLM.

**What it provided:**

- A generic `/script` slash command for executing arbitrary shell scripts from the chat box
- Script path resolution relative to the project root
- Captured stdout, stderr, and exit code, formatted into the LLM's context for follow-up discussion
- Preferred bash, fell back to sh if bash was unavailable

**Why it was retired:**

- **Required an LLM round-trip to actually run** — The plugin intercepted the command before the LLM saw it, but the result still had to be served back through the LLM in order to be acted on. There was no way to invoke a script and use its output without paying for a model turn.
- **Yet another artifact for the user to remember** — `/script` was a generic, content-free command. Using it required the user to remember the script's path and arguments, on top of remembering that `/script` exists. From a UX standpoint it added a layer of indirection without adding value over just running the script directly.
- **Replaced by thin `/command` wrappers** — Specific scripts are now exposed as their own slash commands. Each command is a one-line `.md` file under `src/commands/` whose body tells the agent to run a sibling `.sh` file. The user types a memorable, purpose-specific command (e.g. `/session-tokens`) instead of a generic runner with a path argument. See [`src/commands/session-tokens/`](https://github.com/hgraca/telamon/tree/main/src/commands/session-tokens) for the canonical pattern.

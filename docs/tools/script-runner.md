---
layout: page
title: Script Runner
description: OpenCode plugin that runs shell scripts via the /script command.
nav_section: docs
---

Script Runner — Shell Script Execution for the LLM

An OpenCode plugin that intercepts `/script <path> [args...]` commands, resolves the path relative to the project root, runs the script via bash, and returns stdout, stderr, and the exit code back to the LLM.

- Triggered via the `/script` command inside an OpenCode session
- Resolves the script path relative to the project root
- Prefers bash; falls back to sh if bash is unavailable

**Type:** Built-in OpenCode plugin (`src/plugins/script-runner.js`)

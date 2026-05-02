---
layout: page
title: Discord (Retired)
description: Discord bot integration via remote-opencode — retired because we couldn't make it work reliably.
nav_section: docs
---

# Discord (Retired)

[remote-opencode](https://www.npmjs.com/package/remote-opencode) — a Discord bot that bridged Discord messages to opencode sessions, allowing agents to be triggered from Discord channels.

**What it provided:**

- Discord forum channel integration for triggering agent sessions
- Per-project Discord configuration (`discord_enabled` in telamon.jsonc)
- Automatic bot startup/shutdown via `make up` / `make down`

**Why it was retired:**

- **Couldn't make it work reliably** — The integration never reached a stable state despite multiple attempts. Message bridging, session management, and bot lifecycle all had unresolved issues.
- **Work preserved** — The implementation lives in a separate branch and can be revisited in the future if the upstream package matures or requirements change.

**Branch:** The Discord integration code is preserved in a branch for potential future revival.

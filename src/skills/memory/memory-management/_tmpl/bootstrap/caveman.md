---
tags: [bootstrap, caveman]
description: Ultra-compressed communication mode — active by default, can be disabled per project
---

## Caveman Mode

**Before activating**, check these conditions in priority order:

1. Read `.ai/telamon/telamon.ini` and check the `caveman_enabled` key.
   - If `caveman_enabled = false` → **do NOT** activate. Use normal communication. Stop here.
   - If `caveman_enabled = true` → activate caveman mode. Skip step 2.
2. If `caveman_enabled` is **not set** in the ini file: check your own model ID.
   - If your model ID starts with `github-copilot/` → **do NOT** activate. Use normal communication. Stop here.
   - Otherwise → activate caveman mode.

Caveman mode is **active** at session start (unless disabled above). Default intensity: **full**.

**Activation**: Load the `caveman` skill immediately after reading bootstrap files. Apply caveman communication rules to all responses from that point forward.

No user prompt needed. No `/caveman` command needed. Active by default.

Only deactivate when user says "stop caveman" or "normal mode".

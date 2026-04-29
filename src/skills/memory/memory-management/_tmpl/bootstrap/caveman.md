---
tags: [bootstrap, caveman]
description: Ultra-compressed communication mode — enabled by default, disable per project
---

## Caveman Mode

**Before activating**, read `.ai/telamon/telamon.jsonc` and check the `caveman_enabled` key.

- If `caveman_enabled = true` or the key is missing (default) → activate caveman mode as described below.
- If `caveman_enabled = false` → **do NOT** activate caveman mode. Use normal communication. Skip the rest of this file.

Caveman mode is **inactive** at session start. Default intensity: **full**.

**Activation**: Unless `caveman_enabled = false` in `telamon.jsonc`, load the `caveman` skill immediately after reading bootstrap files. Apply caveman communication rules to all responses from that point forward.

No user prompt needed. No `/caveman` command needed. Activates automatically when enabled in config.

Deactivate when user says "stop caveman" or "normal mode".

---
description: Rewrite AI-generated text to sound natural and human — calibrated to the user's established voice
---

Rewrite the following text to sound natural and human.

## 1. Load Voice Profile

Before rewriting, read `.ai/adk/memory/brain/memories.md` for any entries under a `## Voice` or `## Communication Style` section. These are the user's calibrated writing preferences. Apply them.

If no voice profile exists, infer a voice from the surrounding context of the text (e.g. is this a technical doc, a Slack message, a PR description, an email?).

## 2. Rewrite Principles

- Remove AI tells: "Certainly!", "Of course!", "I'd be happy to", numbered lists when prose works better, excessive hedging, hollow affirmations
- Match the register of the context (casual Slack ≠ formal RFC)
- Prefer short sentences over long compound ones
- Keep the substance — only change the tone and flow, not the meaning
- Do not add new content; cut filler instead

## 3. Output

Provide:
1. The rewritten text (ready to paste)
2. A one-line note on what was changed (e.g. "Removed filler opener, tightened two sentences, changed passive voice to active")

If the rewrite reveals a useful voice calibration insight (e.g. the user always prefers bullet lists for status updates), ask whether to save it to `.ai/adk/memory/brain/memories.md` under a `## Voice` section.

Text to rewrite:
$1

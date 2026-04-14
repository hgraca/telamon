---
description: Prepare a meeting brief — surface relevant context, decisions, and open questions before a meeting or call
---

Prepare a meeting brief for: $1

## 1. Surface Relevant Context

Search for context related to the meeting topic:
- Scan `.ai/adk/memory/brain/key_decisions.md` for standing decisions relevant to the topic
- Scan `.ai/adk/memory/brain/memories.md` for relevant project knowledge
- Scan `.ai/issue/` for active issue folders related to the topic
- Use `cass search "<topic>"` if the codebase contains relevant implementation detail
- Use `ogham search "<topic>"` if the vault contains additional related notes

## 2. Identify Open Questions

List any open questions or ambiguities that the meeting should resolve. Check:
- Unresolved items in `backlog.md` files for related issues
- Any `# TODO` or `# QUESTION` comments in relevant notes
- Decisions marked as tentative in `key_decisions.md`

## 3. Produce the Brief

Output a structured meeting brief:

```markdown
## Meeting: <topic>

**Date**: <today>
**Purpose**: <one-sentence goal of the meeting>

### Context
<2–4 bullet points of the most relevant background>

### Standing Decisions
<any existing decisions this meeting should respect or revisit>

### Open Questions
<what this meeting should answer>

### Suggested Agenda
1. <item>
2. <item>
3. <item>
```

## 4. Optionally Save

If the user wants to save the brief, create `.ai/adk/memory/thinking/meeting-<slug>-<YYYY-MM-DD>.md`.

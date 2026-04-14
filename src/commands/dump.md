---
description: Freeform capture — dump decisions, discoveries, incidents, or notes and route them to the right vault files
---

Process the following freeform dump. For each distinct piece of information:

1. **Classify** it: architectural decision, bug/gotcha, reusable pattern, project update, incident, or general note.
2. **Check existing files**: look in `.ai/adk/memory/brain/` and `.ai/issue/` for a related note that should be updated rather than creating a new one.
3. **Route** to the correct location:

| Content type | Destination |
|---|---|
| Architectural or product decision | `.ai/adk/memory/brain/key_decisions.md` |
| Reusable pattern or best practice | `.ai/adk/memory/brain/patterns.md` |
| Bug, trap, or constraint | `.ai/adk/memory/brain/gotchas.md` |
| General project knowledge | `.ai/adk/memory/brain/memories.md` |
| Active project update | `.ai/issue/<folder>/backlog.md` or relevant artifact |
| Incident note | `.ai/adk/memory/work/incidents/<name>.md` |
| Ephemeral draft or scratch | `.ai/adk/memory/thinking/<descriptive-name>.md` |

4. **Append, don't replace** — add new entries to existing sections rather than overwriting.
5. **Summarise** after processing:
   - What was captured and where each piece was filed
   - Any items that were ambiguous or need user input before filing

Content to process:
$1

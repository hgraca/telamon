---
description: Capture an incident — record what happened, the timeline, root cause, and follow-up actions
---

Capture the following incident into a structured note.

## 1. Create the Note

Create a new file at `.ai/adk/memory/work/incidents/<YYYY-MM-DD>-<slug>.md` where `<slug>` is a short kebab-case label for the incident (e.g. `db-connection-pool-exhausted`).

## 2. Populate the Incident Template

```markdown
# Incident: <title>

**Date**: <YYYY-MM-DD>
**Severity**: <critical | high | medium | low>
**Status**: <open | mitigated | resolved>

## Summary

One-paragraph description of what happened and the impact.

## Timeline

- HH:MM — <event>
- HH:MM — <event>
- ...

## Root Cause

What actually caused it.

## Contributing Factors

Any conditions that allowed the root cause to have an effect.

## Resolution

What was done to stop the incident.

## Follow-up Actions

- [ ] <action> — <owner>
- [ ] <action> — <owner>

## Lessons Learned

What to change to prevent recurrence or reduce impact.
```

## 3. Route Lessons

After writing the note:
- Any **gotcha or trap** revealed → also append to `.ai/adk/memory/brain/gotchas.md`
- Any **pattern or fix** discovered → also append to `.ai/adk/memory/brain/patterns.md`
- Any **standing decision** changed → update `.ai/adk/memory/brain/key_decisions.md`

## 4. Confirm

Report the file path created and any brain notes updated.

Incident details:
$1

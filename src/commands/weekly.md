---
description: Weekly synthesis — review the week's work, capture lessons, and set focus for the coming week
---

Run the weekly review and synthesis.

## 1. Review the Week

Gather what happened across the week:

- `git log --oneline --since="7 days ago" --no-merges` — commits this week
- Scan `.ai/issue/` for issue folders with activity this week (check `DONE.md` files and backlog task statuses)
- Scan `.ai/adk/memory/thinking/` for any notes created this week
- Scan `.ai/adk/memory/work/active/` for notes updated this week

## 2. Surface Lessons

For each significant piece of work done:
- Was there a gotcha or trap encountered? → candidate for `gotchas.md`
- Was a reusable pattern identified? → candidate for `patterns.md`
- Was a decision made? → candidate for `key_decisions.md`

List candidates and ask before writing if there are more than three.

## 3. Promote Thinking Notes

For each file in `.ai/adk/memory/thinking/` that is 5+ days old:
- Completed work? → delete
- Reusable lesson? → promote to brain, delete draft
- Still live WIP? → rename with today's date and keep

## 4. Update Brain Notes

Update `.ai/adk/memory/brain/memories.md` — add a brief `## Week of <YYYY-MM-DD>` entry summarising:
- What shipped or was completed
- What is still in progress
- Key decisions or discoveries

## 5. Set Next Week's Focus

Based on:
- Active issues with remaining tasks in `backlog.md`
- Goals recorded in `key_decisions.md`
- Any carry-over items from this week

Suggest 2–3 focus areas for next week. These are advisory — confirm with the user before writing them anywhere.

## 6. Report

Present a concise weekly summary:
- **Shipped**: completed tasks and merged PRs
- **In progress**: work carrying over
- **Learned**: key lessons, gotchas, patterns
- **Decisions**: standing decisions added or changed
- **Next week**: suggested focus areas

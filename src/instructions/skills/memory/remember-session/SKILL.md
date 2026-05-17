---
name: telamon.remember_session
description: "Unified memory capture — sole storage trigger (besides checkpoints). Scans session since last watermark, routes findings to latent/ notes, promotes thinking/ drafts. Fires automatically on git post-commit (when inside an opencode session), or manually on 'wrap up'."
---

# Remember Session

**Primary memory storage mechanism**. All session learnings flow through this skill.

**Triggers:**
- **Automatic**: git `post-commit` hook fires this when a commit is made inside an opencode session (`$OPENCODE_SESSION_ID` is set). Background, no user report.
- **Manual**: user says "wrap up", "wrapping up", "let's wrap" (produces report)

**This skill replaces** previous multi-trigger approach (`remember_lessons_learned`, `remember_task`, `remember_gotcha` used proactively). Those skills remain as utility references for entry formats, but agents no longer call them proactively during work.

# MUST

- **Load `telamon.memory_management` once, first**: Before step 1, invoke `skill("telamon.memory_management")` exactly once. Do not invoke it again during steps 1–4. This provides the canonical frontmatter schema and routing rules for the entire execution.
- **Silent execution**: Emit ZERO narrative text on automatic (post-commit hook) captures. No "Watermark check", "Nothing since watermark", "Captured X", or any status narration. Tool calls only. Only exception: manual "wrap up" trigger produces report described at end of this skill.
- **No skill-tag echoes**: Do not emit `<skill>telamon.remember_session</skill>` markers as narrative text. Either invoke `skill` tool once (loads skill content) or run steps directly — never both.
- **No headers, no preambles, no recaps**: Do not write heading like "## Capture" or closing line like "Captured 1 gotcha". End response immediately after the last tool call completes.
- **Do NOT call `watermark-session`**: The watermark is written by the hook runner script after the LLM call returns. Never call `watermark-session` from inside this skill.

## 1. Identify what happened

**When triggered by the git hook**, the triggering commit(s) are listed in the prompt — use them directly. Do NOT run `git log` to rediscover them.

**When triggered manually** ("wrap up"), scan the session since the watermark for:
- **Decisions made** — architectural choices, product direction, human stakeholder answers
- **Patterns discovered** — approaches that worked and should be repeated
- **Gotchas hit** — bugs, traps, constraints, false assumptions
- **Work completed** — issue folders touched, tasks finished
- **Rules given** — new rules or constraints from stakeholder

Also check `.ai/telamon/memory/thinking/` for scratch files from this session.

**If nothing worth capturing**: exit immediately. Skip steps 2-4.

## 2. Route to latent notes

Create new files using the frontmatter schema and routing table from the already-loaded `telamon.memory_management` skill (section 2 and section 6):

| Finding                                         | Destination                   | Format                                                                                                                                             |
|-------------------------------------------------|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| Product decision, stakeholder answer, new rule  | `latent/PDRs/`                | New file per item, decision + rationale                                                                                                            |
| Architecture/technical decision                 | `latent/ADRs/`                | New file per item, decision + rationale                                                                                                            |
| Lesson reusable across projects (tech-specific) | `latent/global/<technology>/` | New file per item, lesson + context + scope. Pick most specific bucket from classification table in `telamon.memory_management` skill (section 2). |
| Lesson specific to this project                 | `latent/project/`             | New file per item, lesson + context + scope                                                                                                        |

**Quality gate**: Only save entries that are specific, actionable, and include context. Generic observations ("be careful with X") not worth saving.

## 3. Promote or discard thinking notes

Follow thinking/ lifecycle rules in `telamon.memory_management` skill (section 7):
- Contains reusable lesson → promote to latent/, then delete
- Completed work → delete
- Still live WIP → keep

## 4. Verify vault links

New notes must link to at least one existing note via `[[wikilink]]` (see `telamon.memory_management` skill, section 4).
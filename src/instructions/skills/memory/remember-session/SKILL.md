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

- **Silent execution**: Emit ZERO narrative text on automatic (post-commit hook) captures. No "Watermark check", "Nothing since watermark", "Captured X", "Update watermark, exit", or any status narration. Tool calls only. Only exception: manual "wrap up" trigger produces report described at end of this skill.
- **Single-pass per turn**: Run steps 0-5 exactly ONCE per response. Write watermark file at most ONCE per response.
- **Idempotence guard**: If you have already written watermark file in current response (i.e. already executed step 5), exit immediately. Do not re-execute steps 0-5.
- **No skill-tag echoes**: Do not emit `<skill>telamon.remember_session</skill>` markers as narrative text. Either invoke `skill` tool once (loads skill content) or run steps directly — never both.
- **No headers, no preambles, no recaps**: Do not write heading like "## Capture" or closing line like "Captured 1 gotcha, watermark advanced". Watermark file write IS audit trail.
- **End response immediately after watermark write**: After tool result of write step returns, end response with NO additional text. User should see only tool execution outputs, not commentary.

## 0. Check watermark

Find: `.ai/telamon/memory/thinking/.last-capture-<worktree-dirname>.json`

Where `<worktree-dirname>` is lowercase basename of current working directory.

- If exists: only process content produced *after* recorded `timestamp`.
- If does not exist: first capture for this worktree — process all session content.
- **If nothing happened since watermark** (no commits, no meaningful conversation): update watermark timestamp and exit. Do not produce empty entries.

## 1. Identify what happened

**When triggered by the git hook**, the triggering commit(s) are listed in the prompt — use them directly. Do NOT run `git log` to rediscover them.

**When triggered manually** ("wrap up"), scan the session since the watermark for:
- **Decisions made** — architectural choices, product direction, human stakeholder answers
- **Patterns discovered** — approaches that worked and should be repeated
- **Gotchas hit** — bugs, traps, constraints, false assumptions
- **Work completed** — issue folders touched, tasks finished
- **Rules given** — new rules or constraints from stakeholder

Also check `.ai/telamon/memory/thinking/` for scratch files from this session.

**If nothing worth capturing**: update watermark and exit (step 5). Skip steps 2-4.

## 2. Route to latent notes

Create new files in appropriate latent/ folder per routing table in `telamon.memory_management` skill (section 2):

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

## 5. Update watermark

**MUST**: Run `date -u +"%Y-%m-%dT%H:%M:%SZ"` via bash tool to get the real current UTC timestamp. Never fabricate or guess the timestamp.

Write/update `.ai/telamon/memory/thinking/.last-capture-<worktree-dirname>.json`:

```json
{
  "timestamp": "<output of date -u command>",
  "worktree": "<worktree or directory path>"
}
```
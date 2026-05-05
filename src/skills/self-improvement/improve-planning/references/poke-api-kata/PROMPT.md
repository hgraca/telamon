# Kata: Poke API parser — Improve-Planning Iteration

> **This is an iteration of the `improve-planning` skill.**
> You are the task-solver session. Your job is to execute Phase 1 (planning
> only — **no implementation**) and Phase 2 (interactions report) end-to-end
> without pausing the **human stakeholder** for approval. Agent-to-agent
> handoffs and internal gates (po ↔ architect ↔ critic exchanges) still apply
> normally — what is suppressed is asking the human to confirm decisions.

## Approval policy (read first)

- **Skip only HUMAN-stakeholder approval gates.** Do not ask the human to
  approve the plan, architecture, backlog, or task breakdown. Treat every
  such gate as auto-approved by the human.
- **Keep agent-to-agent gates intact.** The architect still produces the
  plan. The critic still critiques. These exchanges happen between agents
  and do not require human input.
- **No implementation gates apply** because no implementation runs in this
  iteration — Phase 1 stops at FINAL plan.
- **Do not pause to summarise to the human between phases or between agents.**
- The only acceptable reason to stop and ask the human is a hard technical
  failure that no agent can resolve (e.g., a tool returns an error you cannot
  recover from). In that case, write the failure to `interactions.md` under
  a "Blockers" section and proceed to Phase 2 anyway.

## Commit policy (read second)

This iteration folder has its own `.git/` directory, but **only as a
discovery boundary for opencode** — it stops opencode from walking up to the
workspace root and merging unrelated configs. It is NOT a real project
repository and you must NOT commit to it.

- **Do not run `git add`, `git commit`, `git push`, or `git status` against
  this folder.** The `.git/` here exists purely to fence opencode in.
- The orchestrator (`telamon`) agent's normal "commit after any work that
  changes files" rule **does not apply here** — there is no upstream, no
  branch strategy, no history that matters. Skip the commit step entirely.
- The orchestrator's "verify changes are committed" rule when receiving
  subagent results **does not apply here** for the same reason.
- Files written by agents in this folder are the deliverables themselves;
  they exist on disk, that is sufficient.

## Phase 1 — Plan the kata (no implementation)

This iteration evaluates **planning quality**, not implementation. Phase 1
ends when the plan is FINAL — do **not** write production code, do not run
tests, do not refactor anything in `src/`.

Run the full planning workflow as the orchestrator (`telamon`) would for a
real story: PO grooms the backlog, Architect produces the implementation
plan, Critic reviews, iterate until the plan reaches FINAL status. The story
brief is the kata `README.md` plus the integration constraints below.

### Story brief for the planners

The kata project must be refactored to require `get-e/message-bus:dev-main`,
adding these private repositories to `composer.json`:

```json
{"type": "vcs", "url": "git@github.com:GET-E/message-bus.git"},
{"type": "vcs", "url": "git@github.com:GET-E/php-overlay.git"}
```

The plan must assume `vendor/get-e/message-bus/README.ai.md` describes how
to use the message bus and that the implementation will use the bus's
`Dummy` adapter to dispatch commands and query objects synchronously.

### Definition of done for Phase 1

- A FINAL plan exists in the iteration folder (`backlog.md`, architect plan
  document(s), critic review document(s)).
- The Architect's plan has zero open BLOCKERs from the Critic.
- Every backlog task has acceptance criteria, priority, and dependencies.
- The plan satisfies the `plan_story` and `plan_implementation` skills.
- Architecture is sound: directory layout, dependency rules, and naming
  follow the project's architecture rules.

**No code is written, no tests are run, no Docker containers are started in
this phase.** The deliverable is the plan itself.

## Phase 2 — Document the interactions

As soon as Phase 1 finishes (or hits an unrecoverable blocker), proceed
**immediately** to Phase 2 without asking. Do not pause, do not summarise to
the human, do not ask whether to continue.

Document every interaction between agents that happened during this session
in `interactions.md`, using `interactions.template.md` as the template.

The report MUST contain:

- Interaction Flow Diagram
- Statistics summary
- Total agent time (excluding time waiting for human stakeholder input)
- Per-agent time breakdown
- Any blockers encountered

## After Phase 2

Once `interactions.md` is written, output the following message to the user
verbatim and then stop:

> ✅ **Iteration complete.**
>
> Phase 1 (planning) and Phase 2 (interactions report) are done.
>
> **Return to the main improve-planning session** and tell the agent:
>
> > "Evaluate this iteration."
>
> The main session will read the artifacts in this folder, grade the plan
> against the rubric, run root-cause analysis, and propose instruction
> improvements.

Do not start a new task. Do not ask follow-up questions. Stop here.

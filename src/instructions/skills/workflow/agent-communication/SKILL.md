---
name: telamon.agent-communication
description: "Defines structured inter-agent communication protocol. Use when delegating work between agents, handing off artifacts, signalling status, or reporting back to the orchestrating agent."
---

# Skill: Agent Communication

Structured protocol for inter-agent communication in multi-agent system. Handoffs explicit, artifacts traceable, status signals unambiguous.

## When to Apply

- Delegating work between agents (orchestrator to Architect, orchestrator to Developer, etc.)
- Agent completes work and reports back to orchestrating agent
- Agent blocked, needs input from another agent
- Handing off artifacts between stages (planning to implementation, implementation to review)

## Status Signals

Every agent MUST end final message with exactly one signal on its own line:

- `FINISHED!` — Work complete. All deliverables produced. Ready for next stage.
- `BLOCKED: <reason>` — Cannot proceed. Requires input or decision from another agent or human stakeholder.
- `NEEDS_INPUT: <question>` — Can proceed partially but needs clarification on specific point.
- `PARTIAL: <summary of what is done and what remains>` — Session ending with incomplete work. Provides enough context for fresh session to resume.

### Self-verification gate (FINISHED only)

If task deliverable is one or more files, FINISHED message MUST include for each file:

1. **Absolute path**.
2. **Read-back confirmation** — agent MUST read file after writing and include either first line or 1-line summary as proof.
3. **Size or line count**.

FINISHED signal claiming file deliverable but lacking all three items is invalid. Orchestrator treats as stall and re-delegates. Agents failing this gate three times in a row escalate to human stakeholder.

### Action-before-narration gate (all signals)

Before emitting response, run this 3-step check on response text about to send:

1. **Scan last paragraph** for phrases (case-insensitive): "Now I will", "Now let me", "Let me write", "Let me load", "Let me read", "I'll now", "I will now", "Next I'll", "Next let me", "Going to", "Time to".
2. **If matched**: next tool call described by that phrase MUST be in this same response. Append it now.
3. **If cannot append tool call** in this response (waiting on input, ending session, etc.): rewrite last paragraph to NOT describe immediate next action. Replace with status signal (`FINISHED!`, `BLOCKED:`, `NEEDS_INPUT:`, `PARTIAL:`).

Scope: only *immediate next* narrations. Multi-step plan descriptions ("In Step 3 I will…") not in scope.

Orchestrator MUST treat stalled response (narration without matching tool call) as `PARTIAL` and re-delegate with narration removed and action explicit in prompt. Three consecutive stalls of same agent on same task triggers escalation per `telamon.exception-handling`.

## Memory Capture

Memory capture handled **automatically** by remember-session plugin on idle. Agents do NOT need to manually invoke memory skills before returning.

Exceptions:
- **PDRs/ADRs**: When stakeholder answers question or makes decision, PO and Architect should record immediately in `brain/PDRs.md` or `brain/ADRs.md` (too important to defer).
- **Checkpoint**: If context nears overflow, use `telamon.remember_checkpoint`.

## Delegation Format

When delegating work (typically orchestrator delegating to specialist), include these sections:

### Template

> **Task**: One-sentence description of what must be produced.
>
> **Context files** (read before starting):
> - `<path>` — what file contains and why matters
>
> **Deliverable**: What artifact(s) to produce and where to save them.
>
> **Constraints**: Specific rules, boundaries, or things to avoid.
>
> **Acceptance criteria**: How to know work is complete.

### Rules

- Include only files relevant to this specific task — not entire project context.
- When re-delegating after `PARTIAL` signal, include partial output and specify only remaining work.
- When re-delegating after `BLOCKED` signal, resolve blocker first — then re-delegate with resolution.
- Never delegate to multiple roles in single message — one delegation per agent.

### Trust-calibration prompt (developer delegations)

When delegating to @developer (or `telamon.implement_story`) AND agent previously self-reported tests-green on failing tests in this iteration, include all three elements in delegation prompt:

1. **Name past mis-claim** — quote prior FINISHED message and actual test failure that contradicted it. One sentence enough.
2. **Require dual test runs** — instruct agent to run full relevant test suite TWICE consecutively and report both runs verbatim (pass/fail counts from each run).
3. **State independent re-verification** — declare orchestrator WILL re-run tests after FINISHED and stall-ceiling escalation per `telamon.exception-handling` follows on second false-positive.

Apply only after first false-FINISHED in iteration. Default delegations should not carry this overhead.

## Artifact Handoff Contracts

Each transition between agents has defined set of artifacts that MUST be passed:

### Orchestrator to Architect

- Brief or backlog (`backlog.md`)
- Relevant context documents (architecture doc, ADRs)
- Scope constraints and priorities

### Architect to Critic

- Draft plan (`PLAN-ARCH-YYYY-MM-DD-NNN.md`)
- Brief (for scope validation)
- Architecture document and ADR log

### Critic to Architect (feedback loop)

- Plan Review Report (`PLAN-REVIEW-YYYY-MM-DD-NNN.md`)
- Specific findings with file paths and recommendations

### Orchestrator to Tester (pre-implementation)

- Task description from backlog with acceptance criteria
- Architecture plan (for understanding structure)
- Relevant existing test files (for convention alignment)

### Orchestrator to Developer

- Task description from backlog with acceptance criteria
- Architecture plan
- Test files created by Tester
- Concrete class signatures, constructor parameters, file paths from existing codebase

### Orchestrator to Reviewer

- Task description from backlog
- Architecture plan
- Developer's completion summary (`DONE.md`)
- List of files changed

### Reviewer to Developer (feedback loop)

- Review Report (`REVIEW-YYYY-MM-DD-NNN.md`)
- Findings with severity and specific fix recommendations

## Feedback Response Format

When responding to feedback from another agent (e.g. Developer responding to Reviewer findings):

> ### Response to Finding <n>: <Title>
> - **Action**: FIXED | DISPUTED | DEFERRED
> - **Detail**: What changed, or why finding disputed/deferred.
> - **Files modified**: (if FIXED)

## Escalation Handoff

When escalating to different agent or to human stakeholder:

> ### Escalation: <Title>
> - **From**: <role>
> - **To**: <target role or Human Stakeholder>
> - **Reason**: Why this is outside current agent's scope.
> - **Context**: What observed and why matters.
> - **Impact**: What blocked if not resolved.
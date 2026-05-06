---
name: telamon.agent-communication
description: "Defines structured inter-agent communication protocol. Use when delegating work between agents, handing off artifacts, signalling status, or reporting back to the orchestrating agent."
---

# Skill: Agent Communication

Structured protocol for communication between agents in the multi-agent system. Ensures handoffs are explicit, artifacts are traceable, and status signals are unambiguous.

## When to Apply

- When delegating work from one agent to another (orchestrator to Architect, orchestrator to Developer, etc.)
- When an agent completes work and reports back to the orchestrating agent
- When an agent is blocked and needs input from another agent
- When handing off artifacts between stages (planning to implementation, implementation to review)

## Status Signals

Every agent must end its final message with exactly one of these signals on its own line:

- `FINISHED!` — Work is complete. All deliverables produced. Ready for next stage.
- `BLOCKED: <reason>` — Cannot proceed. Requires input or decision from another agent or the human stakeholder.
- `NEEDS_INPUT: <question>` — Can proceed partially but needs clarification on a specific point.
- `PARTIAL: <summary of what is done and what remains>` — Session ending with incomplete work. Provides enough context for a fresh session to resume.

### Self-verification gate (FINISHED only)

If the task's deliverable is one or more files, the FINISHED message MUST include for each file:

1. **Absolute path**.
2. **Read-back confirmation** — the agent must read the file after writing and include either the first line or a 1-line summary as proof.
3. **Size or line count**.

A FINISHED signal that claims a file deliverable but lacks all three items is invalid. The orchestrator will treat it as a stall and re-delegate. Agents that fail this gate three times in a row should be escalated to the human stakeholder.

### Action-before-narration gate (all signals)

Before emitting your response, run this 3-step check on the response text you are about to send:

1. **Scan the last paragraph** for any of these phrases (case-insensitive): "Now I will", "Now let me", "Let me write", "Let me load", "Let me read", "I'll now", "I will now", "Next I'll", "Next let me", "Going to", "Time to".
2. **If matched**: the next tool call described by that phrase MUST be in this same response. Append it now.
3. **If you cannot append the tool call** in this response (waiting on input, ending session, etc.): rewrite the last paragraph to NOT describe an immediate next action. Replace with a status signal (`FINISHED!`, `BLOCKED:`, `NEEDS_INPUT:`, `PARTIAL:`).

Scope: only *immediate next* narrations. Multi-step plan descriptions ("In Step 3 I will…") are not in scope.

The orchestrator MUST treat a stalled response (narration without matching tool call) as `PARTIAL` and re-delegate with the narration removed and the action explicit in the prompt. Three consecutive stalls of the same agent on the same task triggers escalation per `telamon.exception-handling`.

## Memory Capture

Memory capture is handled **automatically** by the remember-session plugin on idle. Agents do NOT need to manually invoke memory skills before returning.

Exceptions:
- **PDRs/ADRs**: When a stakeholder answers a question or makes a decision, PO and Architect should record it immediately in `brain/PDRs.md` or `brain/ADRs.md` (too important to defer).
- **Checkpoint**: If context nears overflow, use `telamon.remember_checkpoint`.

## Delegation Format

When delegating work (typically the orchestrator delegating to a specialist), include these sections:

### Template

> **Task**: One-sentence description of what must be produced.
>
> **Context files** (read these before starting):
> - `<path>` — what this file contains and why it matters
>
> **Deliverable**: What artifact(s) to produce and where to save them.
>
> **Constraints**: Specific rules, boundaries, or things to avoid.
>
> **Acceptance criteria**: How to know the work is complete.

### Rules

- Include only files relevant to this specific task — not the entire project context.
- When re-delegating after a `PARTIAL` signal, include the partial output and specify only the remaining work.
- When re-delegating after a `BLOCKED` signal, resolve the blocker first — then re-delegate with the resolution.
- Never delegate to multiple roles in a single message — one delegation per agent.

## Artifact Handoff Contracts

Each transition between agents has a defined set of artifacts that must be passed:

### Orchestrator to Architect

- The brief or backlog (`backlog.md`)
- Relevant context documents (architecture doc, ADRs)
- Scope constraints and priorities

### Architect to Critic

- Draft plan (`PLAN-ARCH-YYYY-MM-DD-NNN.md`)
- The brief (for scope validation)
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

When responding to feedback from another agent (e.g., Developer responding to Reviewer findings):

> ### Response to Finding <n>: <Title>
> - **Action**: FIXED | DISPUTED | DEFERRED
> - **Detail**: What was changed, or why the finding is disputed/deferred.
> - **Files modified**: (if FIXED)

## Escalation Handoff

When escalating to a different agent or to the human stakeholder:

> ### Escalation: <Title>
> - **From**: <role>
> - **To**: <target role or Human Stakeholder>
> - **Reason**: Why this is outside the current agent's scope.
> - **Context**: What was observed and why it matters.
> - **Impact**: What is blocked if this is not resolved.

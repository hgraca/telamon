# Agent Interactions Log — <Task Name> (Iteration <N>, <YYYY-MM-DD>)

## Overview

Records all inter-agent interactions during the planning (and optionally implementation) of **<task name>** in a single task-solver session.

- **Task**: `<path/to/task/description.md>`
- **Iteration**: `<N>`
- **Workflow(s) used**: `<plan_story>`, `<implement_story>` (or others)
- **Models**: orchestrator=`<id>`, po=`<id>`, architect=`<id>`, critic=`<id>`, developer=`<id>` (etc.)

### Agents Involved

| Agent | Role |
|---|---|
| **<agent>** | <one-line description of what this agent did this session> |
| ... | ... |

---

## Planning Phase

For each interaction, fill out a block. Add as many as occurred. Use the format below verbatim — the evaluator parses these blocks to compute statistics and reconstruct the flow.

### Interaction <N>: <Short title>

- **From**: <agent or "self-initiated">
- **To**: <agent or "—">
- **Channel**: <Task tool / direct message / file artifact>
- **Content**: <what was sent / requested>
- **Response**: <what came back — summarize key items, decisions, refinements, blockers found>
- **Outcome**: <what changed in the plan or world state as a result>
- **Duration (approx)**: <e.g., ~3m> (exclude human wait time)

---

## Implementation Phase (optional — omit if not implemented)

Same format as Planning interactions. Include developer sessions, re-delegations, test/review cycles, commits.

### Interaction <N>: <Short title>

- **From**: <agent>
- **To**: <agent>
- **Channel**: <Task tool / direct>
- **Content**: <what was requested>
- **Response**: <files created, tests added, commits, issues hit>
- **Outcome**: <state change>
- **Duration (approx)**: <e.g., ~6m>

---

## Interaction Flow Diagram

ASCII or mermaid diagram of the agent interaction graph for this session. Show the order, branching, and re-delegations.

```
Human Stakeholder
    |
    | (start task)
    v
   <orchestrator> -----> <agent> (<purpose>)
    |
    ...
```

---

## Summary Statistics

| Metric | Value |
|---|---|
| Total agent interactions | <N> |
| Unique agents involved | <N> (<list>) |
| Planning interactions | <N> |
| Implementation interactions | <N> |
| Architect invocations | <N> |
| Critic invocations | <N> |
| Critic rounds | <N> |
| Developer invocations | <N> |
| Re-delegations (failed/interrupted attempts) | <N> |
| Tasks completed | <N> |
| Total commits | <N> |
| Tests at completion | <N> tests, <N> assertions |
| Code coverage | <%> of src/ |
| Static analysis | <pass/fail> at <level> |

### Per-Task Breakdown (implementation only)

| Task | Session | Tests | Commit |
|---|---|---|---|
| <id> — <name> | <session ref> | <test summary> | `<sha>` |
| ... | ... | ... | ... |

### Key Decisions

| Decision | Rationale |
|---|---|
| <decision> | <why> |

### Agent Processing Time

Exclude human stakeholder wait time. Estimate from observed interaction durations.

#### Planning Phase

| Interaction | Agent(s) | Approx. Duration | Notes |
|---|---|---|---|
| 1. <name> | <agent> | ~Nm | <notes> |
| **Planning subtotal** | | **~Nm** | |

#### Implementation Phase (omit if not implemented)

| Interaction | Agent | Approx. Duration | Notes |
|---|---|---|---|
| <N>. <name> | <agent> | ~Nm | <notes> |
| **Implementation subtotal** | | **~Nm** | |

#### Per-Agent Totals

| Agent | Total Time | Invocations | Notes |
|---|---|---|---|
| <agent> | ~Nm | <N> | <notes> |
| **Total agent processing** | **~Nm** | **<N> subagent invocations** | |

#### Session Totals

| Metric | Value |
|---|---|
| **Planning phase** | ~Nm |
| **Implementation phase** | ~Nm |
| **Total session (agent processing)** | **~Nm** |
| Human stakeholder wait time | excluded |

---

## Cross-Iteration Comparison (filled by evaluator session)

> Leave blank — the evaluator session populates this row in `iterations_quality.md`, not here.

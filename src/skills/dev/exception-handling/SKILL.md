---
name: adk.exception-handling
description: "Provides structured error taxonomy and recovery strategies for agent failures. Use when a session stalls, a tool fails, instructions conflict, tests loop, or any unexpected situation arises during agent work."
---

# Skill: Exception Handling and Recovery

Structured approach to identifying, classifying, and recovering from failures during agent work. Prevents unproductive loops and ensures failures are handled systematically rather than through ad-hoc guessing.

## When to Apply

- When an agent session stalls or produces no usable output
- When a tool call fails or returns unexpected results
- When tests fail in a loop without progress
- When instructions conflict or are ambiguous
- When context is insufficient to proceed
- When scope creep is detected

## Error Taxonomy

### E1: Stalled Session

**Symptoms**: Agent produces repetitive output, enters infinite loops, or stops making progress.

**Recovery**:
1. Inspect working directory for partial progress.
2. Save a partial progress note to `<proj>/.ai/adk/memory/thinking/YYYY-MM-DD-HH:MM:SS-<task>-partial.md` summarising what is done and what remains.
3. Signal `PARTIAL: <summary of what is done and what remains>`.
4. PO re-delegates only incomplete work to a fresh session with explicit context.
5. Never re-delegate already-completed work.

### E2: Conflicting Instructions

**Symptoms**: Two or more context files, skills, or plan steps contain contradictory guidance.

**Recovery**:
1. Identify the conflicting sources (file paths, line numbers).
2. Signal `BLOCKED: Conflicting instructions` with the specifics.
3. Do not guess which instruction takes precedence — escalate to the PO or human stakeholder.
4. PO resolves the conflict and updates the authoritative source.

### E3: Tool Failure

**Symptoms**: An MCP tool or CLI command returns an error, times out, or produces unexpected output.

**Recovery**:
1. Retry once with the same parameters.
2. If retry fails, check if the issue is environmental (container down, network issue).
3. If environmental, signal `BLOCKED: Tool failure — <tool name>: <error message>`.
4. If not environmental, try an alternative approach that achieves the same goal.
5. Document the failure and workaround in the task report.

### E4: Test Loop

**Symptoms**: Tests fail, the fix is applied, but the same or different tests fail again — three or more iterations without convergence.

**Recovery**:
1. Stop modifying code.
2. Re-read the failing test(s) and the code under test from scratch.
3. Identify whether the issue is in the test, the code, or the plan.
4. If the plan seems wrong, escalate to the Architect.
5. If the test seems wrong, escalate to the Tester (or PO if acting as orchestrator).
6. Never apply a fourth fix attempt without a fresh analysis.

### E5: Context Overflow

**Symptoms**: Too much information loaded, agent loses track of earlier instructions, or output quality degrades.

**Recovery**:
1. Signal `PARTIAL: Context limit approaching`.
2. Summarize progress and remaining work.
3. PO re-delegates with only the essential context for remaining work.
4. Do not attempt to continue with degraded output quality.

### E6: Scope Creep

**Symptoms**: Implementation drifts beyond what the plan specifies — new features, refactors, or improvements not in the acceptance criteria.

**Recovery**:
1. Stop the unplanned work.
2. Complete only what the plan specifies.
3. Document the potential improvement as a follow-up suggestion in the task report.
4. Escalate to PO for prioritization if the unplanned work seems important.

### E7: Missing Precedent

**Symptoms**: The plan instructs creation of something with no existing example in the codebase to follow. The agent cannot determine the correct conventions.

**Recovery**:
1. Search sibling directories and files for the closest analog.
2. If no analog exists, signal `NEEDS_INPUT: No existing precedent for <what>. How should this be structured?`
3. Wait for guidance from the Architect or PO before proceeding.

## Recovery Decision Tree

```
Failure detected
  |
  ├── Is it a tool/environment issue? → E3: Retry, then BLOCKED
  ├── Are instructions contradictory? → E2: BLOCKED with specifics
  ├── Is the session making progress? 
  |     ├── No → E1: PARTIAL, re-delegate
  |     └── Yes, but tests keep failing → E4: Stop, fresh analysis
  ├── Is output quality degrading? → E5: PARTIAL, summarize
  ├── Is work going beyond the plan? → E6: Stop, document follow-up
  └── Is there no example to follow? → E7: NEEDS_INPUT
```

## Escalation Triggers

Escalate immediately (do not attempt further recovery) when:

- The same error occurs three times after applying different fixes
- Two or more context files contain irreconcilable contradictions
- The plan step requires a capability the agent does not have
- A security-sensitive operation fails (credentials, permissions, external APIs)
- The agent detects data loss or irreversible state changes

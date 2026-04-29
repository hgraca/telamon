---
name: telamon.elicitation
description: "Structured elicitation methods catalog for deepening requirements, challenging assumptions, and exploring alternatives. Use when requirements feel thin, a decision needs deeper exploration, or assumptions need stress-testing."
---

# Skill: Elicitation

Run a structured elicitation session to surface hidden requirements, challenge assumptions, and explore alternatives before committing to a direction.

## When to Apply

- Requirements feel thin, vague, or assumed rather than validated
- A decision has significant consequences and deserves stress-testing
- Stakeholder says "just do X" but the why is unclear
- Planning reveals conflicting assumptions
- A design feels right but hasn't been challenged
- The `/elicit` command is invoked

## How It Works

Elicitation is a conversation loop, not a one-shot analysis.

1. **Analyze context** — read the current brief, backlog, or decision under review
2. **Suggest 5 methods** — pick methods relevant to the current situation (see catalog in `methods.md`)
3. **Human picks one** — or asks for more options
4. **Apply the method** — run it against the current content, produce structured output
5. **Re-offer** — present 5 new method suggestions (or same if still relevant); loop until human says "done" or "enough"

## Procedure

### Step 0: Load context

Read whatever is available:
- Current brief or story description
- Existing backlog (if any)
- Architecture notes (if any)
- Key decisions log (`.ai/telamon/memory/brain/key_decisions.md`)

Identify: What is the core question or decision? What assumptions are baked in? What is most at risk?

### Step 1: Suggest methods

Present exactly **5 method suggestions** in this format:

```
## Elicitation Options

Given: [1-sentence summary of current context]

Pick a method to apply:

1. **[Method Name]** — [one-line description of what it does and why it fits here]
2. **[Method Name]** — [one-line description]
3. **[Method Name]** — [one-line description]
4. **[Method Name]** — [one-line description]
5. **[Method Name]** — [one-line description]

Or: "more options" for 5 different methods, "done" to finish.
```

Selection logic — prefer methods that:
- Target the weakest part of the current requirements
- Haven't been applied yet in this session
- Match the current phase (early exploration → core/creative; late validation → risk/competitive)

### Step 2: Apply chosen method

Run the method. Each method has a defined output pattern (see catalog). Produce that output clearly and concisely.

After output, always append:

```
---
Apply another method? (pick from above, say "more options", or "done")
```

### Step 3: Loop

After each application, re-offer 5 suggestions. Rotate in fresh methods. Retire methods already applied unless re-applying adds value.

Terminate when:
- Human says "done", "enough", "stop", or "that's good"
- All high-value methods for this context have been applied
- Human signals they have enough to proceed

### Step 4: Synthesis (optional)

If human asks for a summary, produce:

```
## Elicitation Summary

**Methods applied**: [list]
**Key insights**: [bullet list of what was discovered]
**Assumptions surfaced**: [bullet list]
**Risks identified**: [bullet list]
**Recommended next step**: [one sentence]
```

## Method Selection Heuristics

| Situation | Recommended categories |
|-----------|----------------------|
| Early-stage, vague brief | Core, Creative, Research |
| Decision with high stakes | Risk, Competitive, Advanced |
| Multiple stakeholders involved | Collaboration, Core |
| Technical design under review | Technical, Risk, Advanced |
| Assumptions need challenging | Core, Philosophical, Competitive |
| Looking for alternatives | Creative, Research, Advanced |
| Post-implementation review | Retrospective, Risk |

## Full Method Catalog

See `methods.md` in this skill folder for the complete catalog (~35 methods across 10 categories).

Quick reference by category:

**Core**: First Principles, 5 Whys, Socratic Questioning, Jobs-to-be-Done, MoSCoW Prioritization, Assumption Mapping
**Risk**: Pre-mortem Analysis, Red Team / Blue Team, Failure Mode Analysis, Risk Heatmap, Reversibility Check
**Collaboration**: Stakeholder Round Table, Expert Panel Review, Silent Brainstorm, Perspective Walk
**Creative**: SCAMPER, Reverse Engineering, What-If Scenarios, Crazy Eights, Inversion
**Technical**: Architecture Decision Record Probe, Rubber Duck Debugging, Constraint Mapping, Interface-First Design
**Competitive**: Shark Tank Pitch, Debate Club Showdown, Devil's Advocate
**Advanced**: Tree of Thoughts, Self-Consistency Validation, Counterfactual Reasoning
**Research**: Analogous Domain Transfer, Benchmark Comparison, Literature Pattern Mining
**Philosophical**: Chesterton's Fence, Goodhart's Law Check, Second-Order Thinking
**Retrospective**: Five Whys on Failure, Stop-Start-Continue, Blameless Post-mortem

## MUST

- Always suggest exactly 5 methods — not more, not fewer
- Always apply the method's defined output pattern — don't improvise the format
- Always re-offer after each application
- Never apply a method without explaining what it will do first
- Keep method applications focused — one method, one output, then pause

## MUST NOT

- Apply multiple methods at once without human selection
- Produce a synthesis unless asked
- Continue looping after human signals done
- Invent methods not in the catalog (suggest "more options" instead)

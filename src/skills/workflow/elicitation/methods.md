# Elicitation Methods Catalog

~35 methods across 10 categories. Each entry: **name**, description, output pattern, when to use.

---

## Core

Foundational methods. Apply when requirements are vague, assumptions are untested, or the "why" is unclear.

### 1. First Principles Analysis
Break the problem down to its fundamental truths, stripping away assumptions and analogies. Ask: what do we know for certain? What are we assuming?

**Output**: Numbered list of verified facts vs. assumptions. One-sentence restatement of the problem from first principles.

**When**: Brief relies heavily on "how it's always been done" or analogies to other systems.

---

### 2. Five Whys
Ask "why?" five times in sequence to trace a symptom back to its root cause or core motivation.

**Output**: Chain of 5 why/answer pairs. Root cause statement at the bottom.

**When**: A requirement or constraint exists but its origin is unclear. Useful for "we need X" statements.

---

### 3. Socratic Questioning
Challenge every claim with probing questions: What do you mean by X? How do you know? What's the evidence? What if the opposite were true?

**Output**: List of claims from the brief, each followed by 2–3 probing questions that expose gaps or assumptions.

**When**: Requirements are stated with high confidence but haven't been stress-tested.

---

### 4. Jobs-to-be-Done
Reframe features as jobs a user is trying to accomplish. "When I [situation], I want to [motivation], so I can [outcome]."

**Output**: 3–5 JTBD statements derived from the brief. Highlight any features that don't map to a clear job.

**When**: Requirements are feature-centric rather than outcome-centric. Useful for spotting over-engineering.

---

### 5. MoSCoW Prioritization
Classify every requirement as Must Have, Should Have, Could Have, or Won't Have. Force trade-offs.

**Output**: Four-column table with requirements sorted. Flag any "Must Have" items that could be demoted.

**When**: Scope is unclear or everything feels equally important. Use before backlog creation.

---

### 6. Assumption Mapping
List all assumptions baked into the current plan. Rate each by importance (high/low) and certainty (known/unknown). Focus on high-importance, low-certainty assumptions.

**Output**: 2×2 grid (importance vs. certainty). Top 3 assumptions to validate first.

**When**: Early planning. Especially useful when the team has strong opinions but limited data.

---

## Risk

Surface what could go wrong before it does.

### 7. Pre-mortem Analysis
Imagine the project has failed catastrophically. Work backwards: what went wrong? Forces the team to articulate failure modes they're currently ignoring.

**Output**: Narrative: "It's 6 months from now and this failed because..." followed by 5–7 specific failure causes ranked by likelihood.

**When**: Before committing to a plan. Especially useful when the team is overly optimistic.

---

### 8. Red Team / Blue Team
Split the requirements into two perspectives: Red Team argues why this will fail or be wrong; Blue Team defends. Structured adversarial review.

**Output**: Red Team: 5 strongest objections. Blue Team: responses to each. Net assessment: which objections remain unresolved?

**When**: A plan feels solid but hasn't faced real opposition. Good for high-stakes decisions.

---

### 9. Failure Mode Analysis
For each major component or feature, ask: how could this fail? What's the impact? What's the likelihood? What's the detection mechanism?

**Output**: Table with columns: Component | Failure Mode | Impact (H/M/L) | Likelihood (H/M/L) | Mitigation.

**When**: Technical design review. Before writing acceptance criteria for complex features.

---

### 10. Risk Heatmap
Enumerate risks across dimensions (technical, business, timeline, people). Plot on a 3×3 likelihood × impact grid.

**Output**: Heatmap grid with risks placed. Top 3 risks in the high-likelihood/high-impact quadrant with proposed mitigations.

**When**: Project kickoff or when scope expands significantly.

---

### 11. Reversibility Check
For each major decision, ask: is this reversible or irreversible? Irreversible decisions deserve more scrutiny and slower process.

**Output**: List of decisions in the plan, each tagged Reversible / Partially Reversible / Irreversible. Flag irreversible ones for deeper review.

**When**: Architecture decisions, data model choices, third-party integrations.

---

## Collaboration

Surface perspectives that aren't in the room.

### 12. Stakeholder Round Table
Enumerate all stakeholders (users, operators, business owners, adjacent teams). For each, ask: what do they want? What do they fear? What would they veto?

**Output**: Table: Stakeholder | Goal | Fear | Veto condition. Highlight conflicts between stakeholders.

**When**: Requirements come from one stakeholder but affect many. Useful for surfacing hidden constraints.

---

### 13. Expert Panel Review
Simulate consulting 3–5 domain experts (e.g., security expert, UX researcher, ops engineer, domain specialist). What would each say about the current plan?

**Output**: One paragraph per expert persona: their perspective, their top concern, their recommendation.

**When**: Team lacks expertise in a specific domain relevant to the decision.

---

### 14. Silent Brainstorm
Generate ideas or requirements independently before discussion. Prevents anchoring on the first idea raised.

**Output**: 10–15 raw ideas or requirements, unfiltered. Then group by theme. Then vote (mark top 3).

**When**: Brainstorming sessions where one voice dominates or the brief is too narrow.

---

### 15. Perspective Walk
Examine the problem from 3 different user perspectives: a power user, a first-time user, and a user under stress (time pressure, bad connection, cognitive load).

**Output**: For each perspective: what they need, what would frustrate them, what they'd miss. Requirements that only appear for one perspective are flagged.

**When**: UX-heavy features. Accessibility and edge-case discovery.

---

## Creative

Generate alternatives and challenge the obvious solution.

### 16. SCAMPER
Apply seven creative lenses to the current solution: **S**ubstitute, **C**ombine, **A**dapt, **M**odify/Magnify, **P**ut to other uses, **E**liminate, **R**everse/Rearrange.

**Output**: One idea per lens (7 total). Mark the 2 most promising for further exploration.

**When**: The current design feels like the obvious solution and alternatives haven't been considered.

---

### 17. Reverse Engineering
Start from the desired outcome and work backwards. What must be true for this to succeed? What must exist? What must happen first?

**Output**: Backwards chain from goal to current state. Each step: "For X to happen, Y must already be true." Gaps in the chain are requirements.

**When**: Goal is clear but the path is fuzzy. Useful for discovering hidden dependencies.

---

### 18. What-If Scenarios
Stress-test the design with extreme hypotheticals: What if 10× the expected users? What if the third-party API disappears? What if the requirement changes in 6 months?

**Output**: 5 what-if scenarios with: scenario description, impact on current design, adaptation required.

**When**: Design feels brittle or over-fitted to current assumptions.

---

### 19. Crazy Eights
Generate 8 radically different approaches to the same problem in rapid succession. No filtering — quantity over quality.

**Output**: 8 one-sentence approaches, each taking a different angle. Then: which 2 are worth exploring further and why?

**When**: Stuck in one solution frame. Good for breaking out of "we've always done it this way."

---

### 20. Inversion
Instead of asking "how do we succeed?", ask "how do we guarantee failure?" Then invert the failure conditions into success requirements.

**Output**: 5–7 ways to guarantee failure. Inverted as positive requirements. Compare to existing requirements — what's missing?

**When**: Requirements feel incomplete. Good complement to Pre-mortem.

---

## Technical

Probe technical assumptions and design decisions.

### 21. Architecture Decision Record Probe
For each significant technical choice in the plan, ask: what are the alternatives? What are the trade-offs? What are the constraints that make this the right choice?

**Output**: For each decision: Decision | Alternatives considered | Constraints | Trade-offs | Confidence (H/M/L).

**When**: Technical plan has implicit decisions that haven't been made explicit.

---

### 22. Rubber Duck Debugging
Explain the design or requirement out loud, step by step, as if to someone who knows nothing. The act of explaining surfaces gaps.

**Output**: Plain-language walkthrough of the design. Flag every point where the explanation required an assumption or hand-wave.

**When**: Design feels clear in your head but hasn't been articulated. Good before writing specs.

---

### 23. Constraint Mapping
List all constraints: technical (language, framework, infra), business (budget, timeline, compliance), and team (skills, size). For each, ask: is this a real constraint or an assumed one?

**Output**: Table: Constraint | Type | Real or Assumed | Impact if removed. Flag assumed constraints that could be challenged.

**When**: Design feels over-constrained. Useful for finding unnecessary limitations.

---

### 24. Interface-First Design
Define the public interface (API, UI, contract) before any implementation. Ask: what does the caller need? What should be hidden?

**Output**: Draft interface definition (API endpoints, function signatures, or UI wireframe). List of decisions deferred to implementation.

**When**: Multiple components need to integrate. Prevents implementation details leaking into contracts.

---

### 25. Load and Scale Probe
Ask: what happens at 10×, 100×, 1000× current load? Where does the design break? What's the first bottleneck?

**Output**: Scale assumptions in the current design. First bottleneck at each order of magnitude. Mitigation options.

**When**: Performance requirements are vague or assumed to be "good enough."

---

## Competitive

Challenge the plan through adversarial framing.

### 26. Shark Tank Pitch
Present the plan as a business pitch to skeptical investors. They will ask: why this? why now? why you? what's the risk? what's the return?

**Output**: 60-second pitch. Then: 5 tough investor questions with honest answers. Identify which questions expose real weaknesses.

**When**: Business case for a feature hasn't been articulated. Good for prioritization decisions.

---

### 27. Debate Club Showdown
Assign one side to argue strongly for the current approach, another to argue for the strongest alternative. Structured debate format.

**Output**: Pro argument (3 strongest points). Con argument (3 strongest points). Rebuttal round. Verdict: which argument is stronger and why?

**When**: Two competing approaches exist and the team is anchored on one without fully evaluating the other.

---

### 28. Devil's Advocate
Assign one voice to argue against every assumption in the plan. The goal is not to win — it's to find the weakest points.

**Output**: 7–10 devil's advocate challenges to the current plan. For each: is this a real concern or a strawman? If real, what's the mitigation?

**When**: Team has reached consensus too quickly. Good for surfacing groupthink.

---

## Advanced

Structured reasoning techniques for complex decisions.

### 29. Tree of Thoughts
Explore a decision as a tree: root is the current state, branches are options, leaves are outcomes. Evaluate multiple paths before committing.

**Output**: Tree diagram (text format). Root → 3 branches → 2–3 leaves each. Score each leaf: desirability (H/M/L) and feasibility (H/M/L). Recommended path.

**When**: Decision space is large and options are interdependent. Prevents tunnel vision on one path.

---

### 30. Self-Consistency Validation
Generate 3 independent answers to the same question using different reasoning approaches. Check if they converge. Divergence reveals uncertainty.

**Output**: Question stated. Three independent analyses (each 2–3 sentences). Convergence assessment: do they agree? Where do they diverge? What does divergence mean?

**When**: High-stakes decision where confidence is important. Good for validating architectural choices.

---

### 31. Counterfactual Reasoning
Ask: what would have to be different for the opposite decision to be correct? What world would make the alternative the right choice?

**Output**: Current decision stated. Counterfactual world described (3–5 conditions). Assessment: how likely is that world? Should we hedge?

**When**: Committed to a direction but want to understand what would invalidate it.

---

## Research

Ground decisions in evidence and analogies.

### 32. Analogous Domain Transfer
Find a solved problem in a different domain that is structurally similar. What did they learn? What can we borrow?

**Output**: Analogous domain identified. 3 lessons from that domain. How each applies (or doesn't) to the current problem.

**When**: Problem feels novel but is likely solved elsewhere. Good for avoiding reinventing the wheel.

---

### 33. Benchmark Comparison
Compare the current plan against known benchmarks: industry standards, competitor approaches, or internal past projects.

**Output**: 3–5 benchmarks. For each: how does the current plan compare? Better, worse, or different? What can we learn?

**When**: Requirements lack measurable targets. Good for setting acceptance criteria.

---

### 34. Literature Pattern Mining
Ask: what patterns, frameworks, or prior art exist for this problem? What has been written about it?

**Output**: 3–5 relevant patterns or frameworks. For each: what it addresses, how it applies, what it doesn't cover.

**When**: Technical or architectural decision with established best practices that haven't been consulted.

---

## Philosophical

Challenge the deeper "why" behind requirements.

### 35. Chesterton's Fence
Before removing or changing something, ask: why does it exist? If you can't explain why the fence is there, don't remove it yet.

**Output**: For each proposed change: what is being removed or altered? Why does it currently exist? Is the original reason still valid?

**When**: Refactoring, migration, or simplification work. Prevents removing things that exist for non-obvious reasons.

---

### 36. Goodhart's Law Check
When a metric becomes a target, it ceases to be a good metric. Ask: are we optimizing for the right thing, or for a proxy that will be gamed?

**Output**: Metrics or success criteria in the current plan. For each: what behavior does optimizing for this incentivize? Could that behavior diverge from the actual goal?

**When**: Acceptance criteria rely heavily on metrics. Good for OKR and KPI review.

---

### 37. Second-Order Thinking
Ask: what happens next? Then what? Most plans optimize for first-order effects and ignore second and third-order consequences.

**Output**: Decision stated. First-order effect. Second-order effect (consequence of the first-order effect). Third-order effect. Are any second/third-order effects undesirable?

**When**: A change has broad system impact. Good for architectural decisions and policy changes.

---

## Retrospective

Learn from what happened, not just what's planned.

### 38. Five Whys on Failure
Apply the Five Whys to a past failure or near-miss. Trace the symptom back to the systemic root cause.

**Output**: Failure event stated. Five why/answer chain. Root cause. Systemic fix (not just a patch).

**When**: Post-incident review. Before repeating a pattern that failed before.

---

### 39. Stop-Start-Continue
Structured retrospective: what should we stop doing? What should we start doing? What is working and should continue?

**Output**: Three lists (Stop / Start / Continue), 3–5 items each. Prioritize: top 1 item from each list to act on immediately.

**When**: End of a sprint, project, or planning cycle. Good for process improvement.

---

### 40. Blameless Post-mortem
Analyze a failure or incident without assigning blame. Focus on system conditions, not individual errors.

**Output**: Timeline of events. Contributing factors (system, process, tooling, communication). What the system made easy that it should have made hard. Three concrete improvements.

**When**: After an incident, outage, or significant miss. Prerequisite: psychological safety.

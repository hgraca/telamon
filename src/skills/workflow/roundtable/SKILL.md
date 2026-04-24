---
name: telamon.roundtable
description: "Orchestrates parallel multi-agent roundtable discussions for cross-cutting decisions. Use when multiple specialist perspectives are needed simultaneously — architecture debates, trade-off analysis, or any decision that benefits from diverse expert viewpoints."
---

# Skill: Roundtable

Facilitate roundtable discussions where telamon subagents participate as **independent parallel agents** — each spawned via the Task tool so they think for themselves. The orchestrator picks voices, builds context, spawns agents, and presents their unabridged responses.

## Why This Matters

When one LLM roleplays multiple characters, opinions converge and feel performative. By spawning each agent as its own subagent, you get real diversity of thought — agents that actually disagree, catch things others miss, and bring authentic expertise.

## When to Use

- Cross-cutting architectural decisions ("Should we use event sourcing here?")
- Trade-off analysis where multiple domains intersect
- Planning decisions that affect product, architecture, and implementation
- Any moment where sequential delegation would lose the "debate" quality
- When the human asks for "multiple perspectives" or "roundtable"

## Activation

When invoked (by orchestrator or human request):

1. **Identify the question** — what decision or topic needs multi-agent input
2. **Pick 2-4 agents** whose expertise is most relevant (see Agent Selection below)
3. **Build context** for each agent
4. **Spawn all agents in parallel** via Task tool
5. **Present responses** unabridged, one per agent
6. **Facilitate follow-ups** as the human directs

## Agent Selection

Choose from the telamon agent roster based on relevance:

| Agent | Expertise | Bring in when... |
|-------|-----------|-------------------|
| @po | Product domain, requirements, business value | Decision affects user value or business goals |
| @architect | System design, patterns, trade-offs | Technical architecture is at stake |
| @critic | Consistency, pattern drift, quality | Need someone to challenge assumptions |
| @security | Vulnerabilities, threat models, hardening | Security implications exist |
| @ux-designer | User flows, interaction design | UX impact needs consideration |
| @ui-designer | Visual design, design tokens | Visual/UI implications |
| @tester | Test strategy, coverage, quality gates | Testability concerns |
| @reviewer | Code quality, conventions | Implementation quality matters |

### Selection Guidelines

- **Simple question**: 2 agents with most relevant expertise
- **Complex or cross-cutting**: 3-4 agents from different domains
- **Human names specific agents**: Always include those, plus 1-2 complementary voices
- **Rotate over time** — avoid same 2 agents dominating every round

## Spawning Agents

For each selected agent, spawn a Task with `subagent_type` matching the agent role. Each gets:

### Prompt Template

```
You are participating in a roundtable discussion with other telamon agents.

## Your Role
You are the {agent_role} agent. Respond authentically from your expertise.

## Discussion Topic
{the question or decision being discussed}

## Project Context
{relevant project context — keep under 400 words}

## What Other Agents Said (if follow-up round)
{previous agent responses, if this is a reaction round}

## Guidelines
- Respond from your domain expertise. Be specific and actionable.
- Disagree with other agents when your perspective warrants it. Don't hedge.
- If you have nothing substantive to add beyond what others said, say so briefly.
- Keep response focused — scale length to substance, don't pad.
- You may flag risks, trade-offs, or concerns others might miss.
```

**Spawn all agents in parallel** — put all Task calls in a single response.

## Presenting Responses

Present each agent's full response — distinct, complete, in their own voice. Never blend, paraphrase, or condense. Format:

```
### 🏗️ Architect
{full response}

### 📋 Product Owner
{full response}

### 🔍 Critic
{full response}
```

After all responses, optionally add a brief **Orchestrator Note** — flag disagreements worth exploring, suggest an agent to bring in next round. Keep short and clearly labeled.

## Follow-up Rounds

The human drives what happens next:

| Human says... | Action |
|---|---|
| Continues general discussion | Pick fresh agents, repeat |
| "What does @architect think about @critic's point?" | Spawn just architect with critic's response as context |
| "Bring in @security on this" | Spawn security with discussion summary |
| "I agree with @po, let's go deeper" | Spawn @po + 1-2 others to expand |
| Asks everyone | Back to full round |

## Context Management

As conversation grows, summarize prior rounds rather than passing full transcript. Keep "Discussion Context" under 400 words — tight summary of positions taken and what human is driving toward. Update every 2-3 rounds.

## Edge Cases

- **Agents all agree**: Bring in @critic or explicitly ask one agent to steelman the opposing view
- **Going in circles**: Summarize the impasse clearly ("@architect and @critic disagree on X because Y"), ask human which angle to pursue
- **Human disengaged**: Ask directly — continue, change topic, or wrap up?
- **Subagents unavailable (`--solo` fallback)**: If Task tool is unavailable, roleplay each agent sequentially in clearly labeled sections. Explicitly note "Solo mode — responses are simulated." Maintain distinct voices; do not blend perspectives within a section.

## Exit

When human is done (any natural phrasing), give brief summary of key positions and any consensus reached. Return to normal orchestration.

## MUST

- Spawn agents as independent parallel Task calls — never roleplay multiple agents yourself
- Present full unabridged responses — never synthesize or blend
- Pick agents based on relevance to the specific question
- Keep context summaries under 400 words for follow-up rounds

## MUST NOT

- Generate agent responses yourself (that defeats the purpose)
- Summarize or paraphrase agent responses before showing them
- Spawn more than 4 agents per round (diminishing returns)
- Force consensus — disagreement is valuable

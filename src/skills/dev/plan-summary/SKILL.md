---
name: telamon.plan-summary
description: "Produces a planning summary report after a planning stage completes. Use when a planning stage finishes and a summary must be written to <issue-folder>/summary.md and presented to the human stakeholder."
---

# Skill: Planning Summary

Produce a structured summary report at the end of a planning stage.

## When to Apply

- When the `plan-story` workflow reaches its summary step
- When the PO completes a planning stage and needs to summarize artifacts, decisions, and next steps

## Procedure

1. Read all artifacts in the `<issue-folder>` (backlog, architecture specs, critic reviews, UI/UX specs, PO decisions).
2. Fill in every section of the template below — do NOT invent a custom format.
3. Write the result to `<issue-folder>/summary.md`.
4. Output the summary to the human stakeholder, as properly formatted Markdown.

## Template

> # Planning Complete — Summary Report
>
> # Issue: Replace scripts and raw K8s manifests with Helm charts
>
> ## Artifacts Produced
> |Document|Path|
> |---|---|
> |<document_title>|<file_path>|
>
> ## Stories (NN active)
> |#|Story|Approach| Effort            | Risk              | Issues |
> |---|---|---|-------------------|-------------------|-------|
> |<NN>|<story_title>|<one_line_description>| <LOW,MEDIUM,HIGH> | <LOW,MEDIUM,HIGH> |NN|
>
> ## Key Critic Findings
> |#| Title                  |Location| Severity                      |
> |---|------------------------|---|-------------------------------|
> |<NN>| <one_line_description> |<where_in_the_plan>| <BLOCKER,WEAKNESS,SUGGESTION> |
>
> ## Key Architect Decisions
> |#| Decision | Rationale |
> |-|----------|-----------|
>
> ## Key Human Decisions
> |#| Question | Decision |
> |-|----------|----------|
>
> ## Next steps
> <next_steps_recommended>
>
> ## Tools used
>
> ### SKILLS
> List skills used by the agent while doing the planning, or "None."
>
> ### MCP tools
> List MCP tools used by the agent while doing the planning, or "None."

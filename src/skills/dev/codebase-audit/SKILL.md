---
name: telamon.codebase-audit
description: "Audits a codebase for pattern drift, inconsistencies, and architectural erosion. Use when performing a holistic review of codebase health, not scoped to a single changeset."
---

# Skill: Codebase Audit

Detect pattern drift, inconsistencies, and architectural erosion holistically across a codebase — not scoped to a single changeset (that is the reviewer's job).

## When to Apply

- When requested by a stakeholder, another agent, or as part of a milestone review
- When performing a holistic assessment of codebase health and consistency

## Inputs

- Full codebase
- Architecture document
- ADR log

## Audit Report

Save to `<issue-folder>/AUDIT-YYYY-MM-DD-NNN.md`.

### Template

> # Codebase Audit Report
>
> **Scope**: What was audited.
>
> ## Strengths
>
> Patterns consistently applied and working well.
>
> ## Findings
>
> _If none: "No findings. Codebase is consistent."_
>
> ### Finding <n>: <Title>
> - **Severity**: CRITICAL | IMPORTANT | MINOR
> - **Pattern**: The convention or rule being violated.
> - **Evidence**: File paths and line numbers (at least two data points).
> - **Problem found**:
> - **Why it matters**:
> - **Recommendation**: Specific, incremental fix (never a wholesale rewrite).
>
> ## Tools used
>
> ### SKILLS
> List skills used by the agent while creating the report, or "None."
>
> ### MCP tools
> List MCP tools used by the agent while creating the report, or "None."

### Severity Definitions

- **CRITICAL** — Causes bugs, data corruption, or fundamental confusion.
- **IMPORTANT** — Will cause problems at scale or under growth.
- **MINOR** — Cosmetic/stylistic inconsistency with no functional impact.

When in doubt between severities, choose the higher one.

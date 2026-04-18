---
name: telamon.ux-design
description: "Creates UX specifications (user flows, screen interactions, states) and validates implementations against UX specs. Use when producing interaction guidance or reviewing implemented UI against a UX spec."
---

# Skill: UX Design

Produce UX specifications defining user flows, screen interaction specs, and states. Validate implementations against UX specs and report gaps.

## When to Apply

- When the PO requests UX work or the Architect needs interaction specifications
- When producing interaction guidance for the UI Designer and Developer
- When validating an implemented feature against the original UX spec

## UX Specification

Save to `<issue-folder>/UX-SPEC-YYYY-MM-DD-NNN.md`.

### Template

> # UX Specification
>
> **Scope**: Flows, screens, or features covered.
>
> ## User Goals
>
> - **Goal <n>**: <description from user's perspective>
>
> ## Flows
>
> ### Flow <n>: <Flow Name>
>
> **Entry point**: Where the user begins.
> **Happy path**: Numbered steps for primary success path.
> **Exit point**: Where the user ends on success.
>
> #### Decision Points
> Branching logic within the flow.
>
> #### Edge Cases
> Scenarios outside the happy path that must be handled.
>
> ## Screen Interaction Specs
>
> ### Screen <n>: <Screen Name>
>
> **Purpose**: What this screen accomplishes.
> **Layout and hierarchy**: Content priority order and spatial relationships.
>
> #### States
>
> | State | Trigger | Behavior | Copy intent |
> |---|---|---|---|
> | Loading | Initial data fetch | Skeleton/spinner; disable interactive elements | — |
> | Empty | No data | Empty state message with primary action | Encourage first action |
> | Success | Action completed | Confirm result; provide next step | Reinforce completion |
> | Error | Validation/server failure | Inline error with recovery guidance | Help user fix |
> | Auth boundary | Insufficient permissions | Explain limitation; offer alternative | Clarify why/what to do |
>
> _Adapt rows to actual states._
>
> #### Interactions
>
> - **Component**: <name>
>   - **Behavior**: Click, hover, focus, keyboard navigation.
>   - **Feedback**: User response.
>   - **Accessibility**: Keyboard shortcut, ARIA role, focus management, screen reader announcement.
>
> #### Responsive Behavior
> How interaction model adapts across breakpoints.
>
> ## UX Acceptance Criteria
>
> Testable, observable, measurable where possible.
>
> ## New Patterns
>
> _If none: "No new patterns introduced."_
>
> ### Pattern <n>: <Name>
> - **What it is**:
> - **Why it's needed**:
> - **Where it applies**:

## UX Validation Report

Save to `<issue-folder>/UX-VALIDATION-YYYY-MM-DD-NNN.md`.

### Template

> # UX Validation Report
>
> **Verdict**: APPROVED | CHANGES REQUESTED
> **Spec reference**: Path to the original UX spec.
>
> ## Findings
>
> _If none: "No findings. Implementation matches the UX spec."_
>
> ### Finding <n>: <Title>
> - **Severity**: CRITICAL | IMPORTANT | MINOR
> - **Screen or flow**:
> - **Expected behavior**:
> - **Actual behavior**:
> - **Impact**:
> - **Recommended fix**:
>
> ## Tools used
>
> ### SKILLS
> List skills used by the agent while working on the task, or "None."
>
> ### MCP tools
> List MCP tools used by the agent while working on the task, or "None."

### Severity Definitions

- **CRITICAL** — Breaks usability or accessibility for a core flow. Must fix.
- **IMPORTANT** — Degrades experience but has workaround. Should fix.
- **MINOR** — Cosmetic/low-impact deviation. Consider fixing.

When in doubt between severities, choose the higher one.

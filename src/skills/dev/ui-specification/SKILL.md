---
name: telamon.ui-specification
description: "Creates implementation-ready UI specifications with design tokens, screen specs, visual states, and acceptance criteria. Use when producing visual design guidance for developers."
---

# Skill: UI Specification

Produce implementation-ready UI specifications covering design tokens, screen-level layouts, component visual states, responsive behavior, and testable acceptance criteria.

## When to Apply

- When the PO requests visual design work
- When the UX Designer hands off wireframes or interaction flows needing visual treatment
- When specifying new UI components or visual patterns

## UI Spec

Save to `<issue-folder>/UI-SPEC-YYYY-MM-DD-NNN.md`.

### Template

> # UI Specification
>
> **Scope**: Screens or components covered.
> **Breakpoints**: (e.g. mobile 375px, tablet 768px, desktop 1280px)
>
> ## Design Tokens
>
> New or modified tokens. Reference existing tokens by name.
>
> | Token name | Value | Usage |
> |---|---|---|
> | e.g. `color-action-primary` | `#1A73E8` | Primary CTA buttons and links |
>
> _If none: "No new tokens. All values reference the existing design system."_
>
> ## Screen Specs
>
> ### Screen <n>: <Screen Name>
>
> **Layout**: Composition, grid, spatial relationships per breakpoint.
>
> #### Component <n>: <Component Name>
> - **Visual states**: Default, hover, active, disabled, focus, error (applicable states only).
> - **Typography**: Font family, size, weight, line height, color token.
> - **Spacing**: Margins, padding, gaps (reference tokens).
> - **Color**: Background, border, text color tokens.
> - **Iconography**: Icon name/description, size, color token.
> - **Responsive behavior**: Adaptation across breakpoints.
> - **Accessibility notes**: Contrast ratio, focus indicator, ARIA-relevant visual cues.
>
> ## Visual Acceptance Criteria
>
> Testable criteria observable without subjective judgment.
>
> ## New Patterns
>
> _If none: "No new patterns introduced."_
>
> ### Pattern: <Name>
> - **What it is**:
> - **Why it's needed**:
> - **Where it applies**:
> - **Tokens**: Associated tokens.
>
> ## Tools used
>
> ### SKILLS
> List skills used by the agent while working on the task, or "None."
>
> ### MCP tools
> List MCP tools used by the agent while working on the task, or "None."

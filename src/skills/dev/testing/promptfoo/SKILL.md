---
name: telamon.testing.promptfoo
description: "Agent evaluation with promptfoo: running evals, interpreting results, adding test cases, writing assertions. Use when running agent evaluations, after changing agent instructions or skills, before merging agent behavior changes."
---

# promptfoo — Agent Evaluation

## When to Apply

| Trigger | Action |
|---------|--------|
| After changing agent instructions (src/agents/*.md) | Run affected evals to check for regressions |
| After adding or modifying skills (src/skills/) | Run evals that exercise the changed skill |
| Before merging agent behavior changes | Run full eval suite |
| After adding a new agent role | Create a new eval config for it |
| Debugging unexpected agent routing | Run request-classification eval |

## Prerequisites

Before first eval run in a project:

```bash
cd tests/agents && npm install
```

This installs `@opencode-ai/sdk` locally. Only needed once per project.

## Running Evals

```bash
# Run all evals
cd tests/agents && npx -y promptfoo eval

# Run a specific eval
cd tests/agents && npx -y promptfoo eval -c evals/request-classification.yaml

# View results in web UI
cd tests/agents && npx -y promptfoo view
```

## Environment

Set `TELAMON_ROOT` before running evals so `custom_agent` paths resolve:

```bash
export TELAMON_ROOT=/path/to/telamon
```

## Eval Structure

Each eval is a standalone YAML file in `tests/agents/evals/`:

```yaml
description: "What this eval tests"

providers:
  - id: "opencode:sdk"
    config:
      working_dir: "../fixtures/<eval-name>"
      custom_agent: "{{env.TELAMON_ROOT}}/src/agents/telamon.md"
      tools: [read, grep, glob, skill]
      permission:
        read: "allow"
        write: "deny"
        bash: "deny"

prompts:
  - "{{request}}"

tests:
  - description: "Test case description"
    vars:
      request: "The prompt to send"
    assert:
      - type: javascript
        value: "output.includes('expected')"
      - type: llm-rubric
        value: "Semantic quality check description"
      - type: cost
        threshold: 0.50
```

## Assertion Types

| Type | Use for |
|------|---------|
| `javascript` | Check output contains expected strings (use OR for flexibility) |
| `llm-rubric` | Semantic quality evaluation (LLM judges the output) |
| `contains-json` | Verify structured output contains expected JSON |
| `cost` | Token cost threshold |
| `latency` | Response time threshold |
| `trajectory:contains` | Verify specific tool calls were made |

## Adding a New Eval

1. Create `tests/agents/evals/<name>.yaml`
2. Create fixture directory `tests/agents/fixtures/<name>/` if needed
3. Define provider config, prompts, test cases, and assertions
4. Run: `cd tests/agents && npx -y promptfoo eval -c evals/<name>.yaml`
5. Iterate on assertions until they meaningfully test the behavior

## Existing Evals

| Eval | Tests |
|------|-------|
| `request-classification` | Agent routes requests to correct specialist |
| `plan-structure` | Planning output has required structure |
| `code-review-quality` | Reviewer catches seeded bugs |

## Notes

- This establishes the "nested skill" pattern — a sub-skill under `dev/testing/`
- Each eval starts an ephemeral opencode server — no session state leakage
- Evals cost real LLM tokens. Use `cost` assertions to cap spending
- `.promptfoo/` cache in `tests/agents/` stores results (gitignored)

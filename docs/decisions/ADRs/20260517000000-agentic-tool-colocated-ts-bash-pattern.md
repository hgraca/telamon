---
date: 2026-05-17
keywords: ["telamon", "agentic-tool", "pattern", "bash", "typescript", "mcp"]
see: ["PDRs/20260517000000-agentic-tools-bash-entry-points-output-types.md"]
---

# ADR: Agentic Tool Structure — Colocated TypeScript Tool + Bash CLI Wrapper

Created by: Herberto
Created time: May 17, 2026
Last edited by: Herberto
Last updated time: May 17, 2026

## Summary

**In context of** building agentic tools that must be usable both by LLM agents (via MCP) and by humans (via CLI),
**facing**
- the need to avoid duplicating output-formatting logic across two entry points
- the requirement (see [PDR: Agentic tools bash scripts entry points and output types](../PDRs/20260517000000-agentic-tools-bash-entry-points-output-types.md)) that every tool ships a bash script with markdown-by-default output while the JS tool defaults to JSON

**we decided for** a colocated pair of files per tool — a TypeScript MCP tool that delegates to a bash script via `Bun.spawn` — **to achieve**
- a single source of formatting logic (the bash script)
- ergonomic CLI usage for humans (markdown default) and efficient agent consumption (JSON default)

**accepting** that the TS tool has a thin delegation layer with no independent formatting logic.

## Context

Telamon ships agentic tools under `src/instructions/tools/<tool-name>/`. Each tool must be callable by an LLM agent through the MCP protocol and by a human developer directly from the terminal. Without a shared entry point, formatting logic would be duplicated: the TS tool would need its own markdown renderer and the bash script would need its own JSON serialiser. The `tree` tool (`src/instructions/tools/tree/`) established the canonical pattern: a bash script owns all output logic and the TS tool is a thin MCP wrapper that spawns the script.

The product rule (PDR linked in `see`) mandates that the bash script defaults to markdown and the JS tool defaults to JSON. Both must accept `--markdown`, `--json`, and `--format <value>` flags to override the default.

## Options

### Option 1 — Colocated TS tool + bash script, TS delegates to bash (decided)

Each tool directory contains `<tool-name>.ts` and `<tool-name>.sh`. The TS tool spawns the bash script, forwarding the `--format` flag. All output logic lives in the bash script.

**Pros**
- Single source of truth for formatting
- Bash script is independently testable from the CLI
- TS tool stays minimal and easy to audit

**Cons**
- TS tool cannot produce output without a bash dependency (acceptable: bash is always available)

### Option 2 — TS tool only, no bash script

The TS tool handles both MCP and CLI invocation. No bash script.

**Pros**
- Single file per tool

**Cons**
- Violates the PDR requirement for a CLI-accessible bash entry point
- Humans cannot invoke the tool without running the MCP server

### Option 3 — Bash script only, no TS tool

The bash script is registered directly as an MCP tool.

**Pros**
- No TypeScript required

**Cons**
- MCP tool registration requires TypeScript (`@opencode-ai/plugin` `tool()` factory)
- No schema validation on tool arguments

## Decision

We adopt **Option 1**: every tool under `src/instructions/tools/<tool-name>/` consists of exactly two colocated files — a TypeScript MCP tool and a bash CLI wrapper — where the TS tool delegates all execution to the bash script.

### TypeScript tool structure

```typescript
import { tool } from "@opencode-ai/plugin"
import path from "path"

export default tool({
  description: "Short description of what the tool does.",
  args: {
    // Tool-specific arguments
    targets: tool.schema
      .array(tool.schema.string())
      .describe("One or more targets to operate on."),
    format: tool.schema
      .enum(["json", "markdown"])
      .optional()
      .default("json")                          // JS tool defaults to JSON
      .describe("Output format: 'json' (default) or 'markdown'"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "<tool-name>.sh")
    const fmt = args.format ?? "json"

    const cmd = ["bash", script, "--format", fmt, ...args.targets]
    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `<tool-name> failed (exit ${exitCode})\n${stderr.trim() || stdout.trim()}`
    }

    if (fmt === "json") {
      try { return JSON.parse(stdout.trim()) } catch { return stdout.trim() }
    }

    return stdout.trim()
  },
})
```

### Bash script structure

```bash
#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/<tool-name>/<tool-name>.sh
# CLI wrapper — outputs markdown (default) or JSON to stdout.
#
# Usage:
#   <tool-name>.sh <target>              # markdown (default)
#   <tool-name>.sh --markdown <target>   # explicit markdown
#   <tool-name>.sh --json <target>       # JSON output
#   <tool-name>.sh --format json <target>
# =============================================================================

set -euo pipefail

FORMAT="markdown"   # bash script defaults to markdown
TARGETS=()
NEXT_IS_FORMAT=false

for arg in "$@"; do
  if $NEXT_IS_FORMAT; then
    FORMAT="${arg}"
    NEXT_IS_FORMAT=false
  elif [[ "${arg}" == "--format" ]]; then
    NEXT_IS_FORMAT=true
  elif [[ "${arg}" == "--markdown" ]]; then
    FORMAT="markdown"
  elif [[ "${arg}" == "--json" ]]; then
    FORMAT="json"
  else
    TARGETS+=("${arg}")
  fi
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Usage: <tool-name>.sh [--markdown|--json|--format markdown|json] <target> [...]" >&2
  exit 1
fi

if [[ "${FORMAT}" == "json" ]]; then
  # Emit structured JSON
  python3 - "${TARGETS[@]}" <<'PYEOF'
import sys, json
targets = sys.argv[1:]
results = []
for t in targets:
    results.append({"target": t, "result": "..."})
print(json.dumps({"status": "ok", "results": results}, indent=2))
PYEOF
else
  # Emit markdown
  for target in "${TARGETS[@]}"; do
    echo "## Result: ${target}"
    echo ""
    echo "..."
    echo ""
  done
fi
```

## Design Constraints

### Tool directory layout

Each tool lives in its own subdirectory: `src/instructions/tools/<tool-name>/`. The directory must contain exactly `<tool-name>.ts` and `<tool-name>.sh`. No other source files are required (shared utilities may be imported from sibling directories).

### Format flag contract

Both files must honour the same three flag forms: `--markdown`, `--json`, `--format markdown`, `--format json`. The TS tool passes the resolved format to the bash script as `--format <value>` — it never passes `--markdown` or `--json` directly, to keep the bash argument parser simple.

### Default asymmetry

The bash script defaults to `markdown`; the TS tool defaults to `json`. This asymmetry is intentional and mandated by the PDR. Do not unify the defaults.

### Rationale

1. **Single formatting source** — all output rendering lives in the bash script. The TS tool never constructs markdown or JSON independently.
2. **CLI ergonomics** — humans running the script from a terminal get readable markdown without extra flags.
3. **Agent efficiency** — agents calling the MCP tool get structured JSON by default, which is cheaper to parse than markdown.
4. **Testability** — the bash script can be exercised with `bash <tool-name>.sh <args>` without starting the MCP server.

## Consequences and Follow-Up Work

To implement this decision, we need to:

- Apply this pattern to every new tool added under `src/instructions/tools/`.
- Audit existing tools (`search-memories`, `git-report`, `format-md`) and align them to this pattern where they deviate.
- Update `src/instructions/skills/self-improvement/create-tool/SKILL.md` to reference this ADR and include the canonical snippets above.

### Proponents: Herberto
### Deciders: Herberto
### Date: 2026-05-17

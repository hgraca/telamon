---
name: telamon.create-tool
description: >
  Creates OpenCode custom tools (JS/TS wrappers LLM can call). Guides tool design,
  implementation, testing, governance. Use when user asks to create a new tool,
  add a custom tool, write a tool definition, or extend agent capabilities with a
  new function. Triggers on "create tool", "new tool", "custom tool", "tool definition",
  "write a tool", "add a tool", "make a tool", or when user describes a capability
  the agent should have (e.g. "I need the agent to query our database", "make the
  agent send Slack messages").
---

# Skill: Create OpenCode Custom Tool

Create custom tool LLM can call. JS/TS wrappers, shell out any language. Filename = tool name.

## When to Apply

- User asks create new tool, custom tool, tool definition
- User describes capability agent should have (query DB, send Slack, run script)
- User says "I need agent to be able to X" where X repeatable action
- User asks extend built-in toolset
- User asks create tool shelling out to Python, PHP, other languages

Do NOT apply when user asks about existing tools, wants use tool, debugging — those are questions.

## Procedure

### Step 0: Gather reqs

Clarify before writing:

1. **What tool do?** — One action. Multiple → separate tools.
2. **Args?** — Minimal. Prefer primitives/enums.
3. **Lang?** — JS/TS wrapper, any lang for work.
4. **Local or global?** — `.opencode/tools/` vs `~/.config/opencode/tools/`.
5. **Permissions?** — Destructive → `require-approval`. Read-only → `allow`.
6. **Dry-run?** — Destructive MUST have dry-run or confirm step.
7. **Secrets?** — Never embed. Load from env vars or secret store.

### Step 1: Design

#### Single responsibility
- One tool = one action. "Query DB + format results" → two tools.
- Prefer several small tools over one large.

#### Security & least privilege
- Minimal args. Every extra arg = attack surface.
- Never embed secrets. Load from `process.env` or secret store.
- Check name shadows built-in (read, write, bash, glob, grep). If so, rename or disable via permissions.

#### Argument schema — MUST

- **Use `args: {}` (empty object) for all Telamon agentic tools.** Zod schemas (`tool.schema`) crash `toJsonSchema` at load time — opencode binary cannot register the tool. `args: {}` is the only safe schema for tools under `src/instructions/tools/`.
- For general project tools (`.opencode/tools/`), `tool.schema` (Zod) may work — verify against the installed opencode version before shipping.
- Every field that IS used: add `.describe()`.
- Prefer `z.string()`, `z.number()`, `z.enum()` over `z.object()`.
- Required = required. Optional → `.optional()`.

#### Naming convention
- Filename = tool name. Use `snake_case.ts` or `kebab-case.ts`.
- Multi-tool: filename becomes prefix (`math_add`, `math_multiply`).
- Do NOT shadow built-in unless intentionally replacing.

### Step 2: Write tool file

#### Telamon agentic tools — colocated TS + bash pattern

**Return value — MUST return a string.** OpenCode calls `.split('\n')` on every tool return value. Returning an object, array, `undefined`, or `null` crashes with `p.split is not a function`. Always return `string`:

```typescript
// CORRECT
return stdout.trim()
return JSON.stringify({ status: "ok", result })
return `error: ${message}`

// WRONG — crashes opencode
return { status: "ok" }          // object
return undefined                  // undefined
return JSON.parse(stdout)         // parsed object
```

**Multi-value args — MUST handle all formats.** When `args: {}` is used, the LLM may pass a multi-value parameter as a native JS array, a JSON array string, a comma-separated string, or a space-separated string. Always normalise before use:

```typescript
function toArray(val: unknown): string[] {
  if (Array.isArray(val)) return val.map(String)
  const s = String(val ?? "").trim()
  if (!s) return []
  // Try JSON array
  if (s.startsWith("[")) {
    try { return (JSON.parse(s) as unknown[]).map(String) } catch {}
  }
  // Comma-separated
  if (s.includes(",")) return s.split(",").map(v => v.trim()).filter(Boolean)
  // Space-separated or single value
  return s.split(/\s+/).filter(Boolean)
}
```

**Never `JSON.parse` stdout and return the result directly.** `JSON.parse` returns an object — returning it crashes opencode. Either return `stdout.trim()` (raw string) or `JSON.stringify(JSON.parse(stdout))` (re-serialised string).

```typescript
// CORRECT — return raw string
return stdout.trim()

// CORRECT — re-serialise if you need to validate JSON
try { return JSON.stringify(JSON.parse(stdout.trim())) } catch { return stdout.trim() }

// WRONG — returns object, crashes opencode
return JSON.parse(stdout.trim())
```

**Partial failure over total abort.** Multi-path tools (e.g. tree, git-report) MUST skip invalid paths and report them, not abort the whole call. Collect errors, continue processing valid inputs, include error summary in return string.

Tools that live under `src/instructions/tools/<tool-name>/` (Telamon's own agentic tools) follow a stricter pattern documented in `docs/decisions/ADRs/20260517000000-agentic-tool-colocated-ts-bash-pattern.md`. Each tool directory contains exactly two files:

- `<tool-name>.ts` — MCP tool wrapper; defaults to **JSON** output; delegates all execution to the bash script.
- `<tool-name>.sh` — CLI wrapper; defaults to **markdown** output; owns all formatting logic.

Both files accept `--json`, `--markdown`, and `--format <value>` flags. The TS tool passes the resolved format to the bash script via `--format <value>` and never formats output itself.

**TS tool (Telamon agentic tool)**

```typescript
import { tool } from "@opencode-ai/plugin"
import path from "path"

export default tool({
  description: "Short description of what the tool does.",
  args: {
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

**Bash script (Telamon agentic tool)**

```bash
#!/usr/bin/env bash
# src/instructions/tools/<tool-name>/<tool-name>.sh
# Defaults to markdown; accepts --json / --markdown / --format <value>.
set -euo pipefail

FORMAT="markdown"   # bash script defaults to markdown
TARGETS=()
NEXT_IS_FORMAT=false

for arg in "$@"; do
  if $NEXT_IS_FORMAT; then
    FORMAT="${arg}"; NEXT_IS_FORMAT=false
  elif [[ "${arg}" == "--format" ]]; then NEXT_IS_FORMAT=true
  elif [[ "${arg}" == "--markdown" ]]; then FORMAT="markdown"
  elif [[ "${arg}" == "--json" ]];     then FORMAT="json"
  else TARGETS+=("${arg}")
  fi
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Usage: <tool-name>.sh [--markdown|--json|--format markdown|json] <target> [...]" >&2
  exit 1
fi

if [[ "${FORMAT}" == "json" ]]; then
  python3 - "${TARGETS[@]}" <<'PYEOF'
import sys, json
targets = sys.argv[1:]
print(json.dumps({"status": "ok", "results": targets}, indent=2))
PYEOF
else
  for target in "${TARGETS[@]}"; do
    echo "## Result: ${target}"
    echo ""
  done
fi
```

Reference implementation: `src/instructions/tools/tree/` (`tree.ts` + `tree.sh`).

#### General project tool — single TS file

Place in `.opencode/tools/<tool-name>.ts` (project) or `~/.config/opencode/tools/<tool-name>.ts` (global).

#### Single-tool file template

```typescript
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Short description of what this tool does. One sentence.",
  args: {
    arg1: tool.schema.string().describe("What this argument is for"),
    arg2: tool.schema.number().describe("Another argument"),
  },
  async execute(args, context) {
    // Use context.directory for session working directory
    // Use context.worktree for git worktree root
    // Your logic here
    return JSON.stringify({ status: "ok", result: "..." })
  },
})
```

#### Multi-tool file template

```typescript
import { tool } from "@opencode-ai/plugin"

export const actionOne = tool({
  description: "Does one thing.",
  args: { /* ... */ },
  async execute(args, context) { /* ... */ },
})

export const actionTwo = tool({
  description: "Does another thing.",
  args: { /* ... */ },
  async execute(args, context) { /* ... */ },
})
```

Creates `<filename>_actionOne` and `<filename>_actionTwo`.

#### Shell-out pattern (Python, PHP, bash)

```typescript
import { tool } from "@opencode-ai/plugin"
import path from "path"

export default tool({
  description: "Runs a Python script to do X.",
  args: {
    input: tool.schema.string().describe("Input data"),
  },
  async execute(args, context) {
    const script = path.join(context.worktree, ".opencode/tools/my-script.py")
    const result = await Bun.$`python3 ${script} ${args.input}`.text()
    return result.trim()
  },
})
```

### Step 3: Permissions

Configure in `.opencode/permissions.jsonc`:

```jsonc
{
  "tools": {
    // Read-only, safe: allow without approval
    "my-read-tool": "allow",
    // Destructive: require explicit approval
    "my-write-tool": "require-approval",
    // Block entirely
    "my-dangerous-tool": "deny"
  }
}
```

### Step 4: Tests

- **Unit tests** for wrapper logic (arg validation, return formatting).
- **Integration tests** for subprocesses or external API calls.
- Tests MUST run in CI.
- Test file: `<tool-name>.test.ts` alongside tool file, or `tests/` mirroring path.

### Step 5: Logging + structured output

- Return structured JSON with fixed keys.
- Include error codes + human-friendly messages on failure.
- Append log entries to `.ai/telamon/logs/<tool-name>.log` (not stdout). Each entry: tool name, args, result, timestamp.

```typescript
import { tool } from "@opencode-ai/plugin"
import path from "path"

export default tool({
  description: "Short description of what this tool does. One sentence.",
  args: {
    arg1: tool.schema.string().describe("What this argument is for"),
  },
  async execute(args, context) {
    const logPath = path.join(context.worktree, ".ai/telamon/logs/my-tool.log")
    try {
      const result = await doSomething(args)
      // Append structured log entry
      await Bun.write(
        logPath,
        JSON.stringify({
          tool: "my-tool",
          args,
          result,
          timestamp: new Date().toISOString(),
        }) + "\n",
      )
      return JSON.stringify({ status: "ok", result })
    } catch (error) {
      return JSON.stringify({
        status: "error",
        code: "MY_TOOL_FAILED",
        message: error instanceof Error ? error.message : String(error),
      })
    }
  },
})
```

### Step 6: Gate check

Check every gate before signalling completion:

| #   | Gate                                                                       | Pass/Fail |
|-----|----------------------------------------------------------------------------|-----------|
| 1   | One action, short description                                              |           |
| 2   | `args: {}` used for Telamon agentic tools; Zod schema only for project tools (verified against opencode version) |           |
| 3   | No secrets in repo; runtime reads from env/secret store                    |           |
| 4   | Permission policy set (allow / deny / require-approval)                    |           |
| 5   | Idempotent or dry-run for destructive actions                              |           |
| 6   | Structured JSON output + error codes                                       |           |
| 7   | Tests (unit + integration) and CI runs them                                |           |
| 8   | Logging to `.ai/telamon/logs/<tool-name>.log` (append-only)                |           |
| 9   | Name follows convention, no built-in shadowing                             |           |
| 10  | Dependencies documented and pinned (runtimes, binaries)                    |           |
| 11  | Example usage in tool file or README                                       |           |
| 12  | Manual-approval gating for risky operations                                |           |
| 13  | Tool in correct folder (`.opencode/tools/` or `~/.config/opencode/tools/`) |           |
| 14  | Changelog entry for capability/permission changes                          |           |
| 15  | Telamon agentic tool: bash entry point `<tool-name>.sh` exists alongside `.ts` (executable, fire-and-forget if background tool) |           |
| 16  | `execute` returns a `string` in all code paths (never object, array, undefined, or raw `JSON.parse` result) |           |
| 17  | Multi-value args normalised with `toArray()` pattern (handles native array, JSON string, comma-sep, space-sep) |           |
| 18  | Multi-path tool: invalid paths skipped and reported, not aborting the whole call |           |

Any gate fails → fix before signalling completion.

### Step 7: Signal done

When tool written, tested, permissions set, all gates pass:

- `FINISHED!` — absolute path, line count, gate checklist result.
- Include example usage so orchestrator knows how to invoke.

## Definitions

| Term                | Meaning                                                             |
|---------------------|---------------------------------------------------------------------|
| `tool.schema`       | Zod schema helper from `@opencode-ai/plugin`. Same as `z` from zod. |
| `context.directory` | Session working dir (not necessarily git root).                     |
| `context.worktree`  | Git worktree root. Use for resolving relative paths.                |
| `Bun.$`             | Bun shell utility for subprocesses. Available in OpenCode runtime.  |
| `require-approval`  | Permission level prompting user before tool executes.               |

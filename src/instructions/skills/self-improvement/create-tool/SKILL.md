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

#### Argument schema
- Use `tool.schema` (Zod) for all inputs. Every field `.describe()`.
- Prefer `z.string()`, `z.number()`, `z.enum()` over `z.object()`.
- Required = required. Optional → `.optional()`.

#### Naming convention
- Filename = tool name. Use `snake_case.ts` or `kebab-case.ts`.
- Multi-tool: filename becomes prefix (`math_add`, `math_multiply`).
- Do NOT shadow built-in unless intentionally replacing.

### Step 2: Write tool file

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
| 2   | Zod schema validates all input fields                                      |           |
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

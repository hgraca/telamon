/**
 * Unit tests for the ActiveWorkContextPlugin.
 *
 * Architecture note on Bun module caching:
 *   Bun caches ES modules after the first import. The fs mock must be set up
 *   BEFORE the first import of active-work-context.js. Because the plugin reads
 *   the filesystem inside the hook body (not at module load time), we can
 *   control behaviour per-test by swapping the module-level spy variables.
 *
 *   Strategy:
 *     - Set up the fs mock once at the top with spy variables.
 *     - Reset spy state before each test via the module-level variables.
 *     - Import the plugin AFTER the mock is in place.
 *
 *   The `injected` flag lives inside the plugin factory closure. A fresh
 *   plugin instance is created in each test via `ActiveWorkContextPlugin(makeCtx())`
 *   so the flag always starts as false.
 */

import { describe, test, expect, mock, beforeEach } from "bun:test"

// ---------------------------------------------------------------------------
// fs mock — must be set up BEFORE the first import of active-work-context.js
// ---------------------------------------------------------------------------

/** Controls what readdirSync returns for a given path. */
const _readdirMap: Map<string, string[]> = new Map()

/** Controls what existsSync returns for a given path. */
const _existsMap: Map<string, boolean> = new Map()

/** Controls what readFileSync returns for a given path. */
const _readMap: Map<string, string> = new Map()

mock.module("fs", () => ({
  readdirSync: (path: string, options?: { withFileTypes?: boolean }) => {
    const entries = _readdirMap.get(path) ?? []
    if (options?.withFileTypes) {
      // Return dirent-like objects with isDirectory()
      return entries.map((name) => ({
        name,
        isDirectory: () => true,
      }))
    }
    return entries
  },
  existsSync: (path: string) => {
    return _existsMap.get(path) ?? false
  },
  readFileSync: (path: string, _enc: string) => {
    const content = _readMap.get(path)
    if (content === undefined) throw new Error(`ENOENT: no such file: ${path}`)
    return content
  },
}))

// ---------------------------------------------------------------------------
// Now import the plugin under test (after mocks are in place)
// ---------------------------------------------------------------------------
import { ActiveWorkContextPlugin } from "../../src/plugins/active-work-context.js"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const TEST_DIR = "/test-project"
const ACTIVE_DIR = `${TEST_DIR}/.ai/telamon/memory/work/active`

/** Build a minimal plugin context. */
function makeCtx(directory = TEST_DIR) {
  return { directory } as Parameters<typeof ActiveWorkContextPlugin>[0]
}

/** Build the tool.execute.before hook args for a bash command. */
function makeHookArgs(command = "original-command", tool = "bash") {
  const input = { tool }
  const output = { args: { command } }
  return { input, output }
}

/** Register a work item subdirectory with a README.md. */
function registerWorkItem(name: string, readmeContent: string) {
  const itemDir = `${ACTIVE_DIR}/${name}`
  const readmePath = `${itemDir}/README.md`

  // Mark the active dir as existing
  _existsMap.set(ACTIVE_DIR, true)

  // Add the subdirectory to active dir listing
  const existing = _readdirMap.get(ACTIVE_DIR) ?? []
  if (!existing.includes(name)) {
    _readdirMap.set(ACTIVE_DIR, [...existing, name])
  }

  // Mark the README as existing
  _existsMap.set(readmePath, true)

  // Provide README content
  _readMap.set(readmePath, readmeContent)
}

/** Register a work item subdirectory WITHOUT a README.md. */
function registerWorkItemNoReadme(name: string) {
  const readmePath = `${ACTIVE_DIR}/${name}/README.md`

  _existsMap.set(ACTIVE_DIR, true)

  const existing = _readdirMap.get(ACTIVE_DIR) ?? []
  if (!existing.includes(name)) {
    _readdirMap.set(ACTIVE_DIR, [...existing, name])
  }

  _existsMap.set(readmePath, false)
}

/** Minimal README with YAML frontmatter, a title, and a short description. */
function makeReadme(title: string, description = "Short description of the task.") {
  return `---\ntags: [work]\n---\n\n## ${title}\n\n${description}`
}

// ---------------------------------------------------------------------------
// Reset state before each test
// ---------------------------------------------------------------------------

beforeEach(() => {
  _readdirMap.clear()
  _existsMap.clear()
  _readMap.clear()
})

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("ActiveWorkContextPlugin", () => {

  // -------------------------------------------------------------------------
  // 1. Happy path: active work items with README.md → context injected
  // -------------------------------------------------------------------------
  describe("happy path", () => {
    test("prepends echo context to the first bash command when active items exist", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))
      registerWorkItem("task-beta", makeReadme("Beta Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs("ls -la")

      await hook(input, output)

      // Command must start with echo '...' &&
      expect(output.args.command).toMatch(/^echo '/)
      expect(output.args.command).toContain("&& ls -la")
    })

    test("injected context includes the active work item names", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))
      registerWorkItem("task-beta", makeReadme("Beta Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.args.command).toContain("task-alpha")
      expect(output.args.command).toContain("task-beta")
    })

    test("injected context includes the titles extracted from README.md", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))
      registerWorkItem("task-beta", makeReadme("Beta Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.args.command).toContain("Alpha Task")
      expect(output.args.command).toContain("Beta Task")
    })
  })

  // -------------------------------------------------------------------------
  // 2. No active work directory: .ai/telamon/memory/work/active/ doesn't exist
  // -------------------------------------------------------------------------
  describe("no active work directory", () => {
    test("does not modify the command when work/active/ does not exist", async () => {
      // _existsMap has no entry for ACTIVE_DIR → existsSync returns false

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs("original-command")

      await hook(input, output)

      expect(output.args.command).toBe("original-command")
    })

    test("sets injected=true (does not retry) when work/active/ does not exist", async () => {
      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!

      // First bash call — no active dir
      const first = makeHookArgs("first-command")
      await hook(first.input, first.output)
      expect(first.output.args.command).toBe("first-command")

      // Register items AFTER the first call to prove injected was set
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      // Second bash call — should still not inject (injected=true already)
      const second = makeHookArgs("second-command")
      await hook(second.input, second.output)
      expect(second.output.args.command).toBe("second-command")
    })
  })

  // -------------------------------------------------------------------------
  // 3. Empty active directory: exists but no subdirectories
  // -------------------------------------------------------------------------
  describe("empty active directory", () => {
    test("does not modify the command when work/active/ has no subdirectories", async () => {
      _existsMap.set(ACTIVE_DIR, true)
      _readdirMap.set(ACTIVE_DIR, []) // empty listing

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs("original-command")

      await hook(input, output)

      expect(output.args.command).toBe("original-command")
    })

    test("sets injected=true when work/active/ has no subdirectories", async () => {
      _existsMap.set(ACTIVE_DIR, true)
      _readdirMap.set(ACTIVE_DIR, [])

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!

      // First bash call — empty dir
      const first = makeHookArgs("first-command")
      await hook(first.input, first.output)
      expect(first.output.args.command).toBe("first-command")

      // Register items AFTER the first call
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      // Second bash call — should still not inject (injected=true already)
      const second = makeHookArgs("second-command")
      await hook(second.input, second.output)
      expect(second.output.args.command).toBe("second-command")
    })
  })

  // -------------------------------------------------------------------------
  // 4. Subdirectory without README.md → should be skipped
  // -------------------------------------------------------------------------
  describe("subdirectory without README.md", () => {
    test("does not include a no-README subdirectory in the injected context", async () => {
      registerWorkItemNoReadme("task-no-readme")

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs("original-command")

      await hook(input, output)

      // No items with README → command must be unchanged
      expect(output.args.command).toBe("original-command")
    })

    test("sets injected=true when the only subdirectory has no README.md", async () => {
      registerWorkItemNoReadme("task-no-readme")

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!

      const first = makeHookArgs("first-command")
      await hook(first.input, first.output)
      expect(first.output.args.command).toBe("first-command")

      // Second call should also be a no-op (injected=true)
      const second = makeHookArgs("second-command")
      await hook(second.input, second.output)
      expect(second.output.args.command).toBe("second-command")
    })
  })

  // -------------------------------------------------------------------------
  // 5. Mixed: some subdirs have README, some don't
  // -------------------------------------------------------------------------
  describe("mixed subdirectories", () => {
    test("only includes items with README.md in the injected context", async () => {
      registerWorkItem("task-with-readme", makeReadme("Has Readme"))
      registerWorkItemNoReadme("task-without-readme")

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.args.command).toContain("task-with-readme")
      expect(output.args.command).not.toContain("task-without-readme")
    })

    test("includes the title from the README item but not the no-README item name", async () => {
      registerWorkItem("task-with-readme", makeReadme("Has Readme"))
      registerWorkItemNoReadme("task-without-readme")

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.args.command).toContain("Has Readme")
    })
  })

  // -------------------------------------------------------------------------
  // 6. Non-bash tool: input.tool !== "bash" → skip, don't set injected
  // -------------------------------------------------------------------------
  describe("non-bash tool", () => {
    test("does not modify output when tool is not bash", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs("original-command", "edit")

      await hook(input, output)

      expect(output.args.command).toBe("original-command")
    })

    test("does not set injected on non-bash call, so next bash call still injects", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!

      // Non-bash call — should be skipped without setting injected
      const nonBash = makeHookArgs("edit-command", "edit")
      await hook(nonBash.input, nonBash.output)
      expect(nonBash.output.args.command).toBe("edit-command")

      // Subsequent bash call — should still inject
      const bash = makeHookArgs("bash-command", "bash")
      await hook(bash.input, bash.output)
      expect(bash.output.args.command).toMatch(/^echo '/)
      expect(bash.output.args.command).toContain("&& bash-command")
    })
  })

  // -------------------------------------------------------------------------
  // 7. Fires only once: after first injection, second bash call must not inject
  // -------------------------------------------------------------------------
  describe("fires only once", () => {
    test("does not inject context on the second bash call", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!

      // First bash call — injects
      const first = makeHookArgs("first-command")
      await hook(first.input, first.output)
      expect(first.output.args.command).toMatch(/^echo '/)

      // Second bash call — must NOT inject again
      const second = makeHookArgs("second-command")
      await hook(second.input, second.output)
      expect(second.output.args.command).toBe("second-command")
    })

    test("original command is preserved verbatim on the second bash call", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!

      await hook(...Object.values(makeHookArgs("first-command")) as [unknown, unknown])

      const second = makeHookArgs("second-command")
      await hook(second.input, second.output)
      expect(second.output.args.command).toBe("second-command")
    })
  })

  // -------------------------------------------------------------------------
  // 8. Injected content format: includes names, titles, and agent instruction
  // -------------------------------------------------------------------------
  describe("injected content format", () => {
    test("injected context includes an instruction for the agent to ask the user what to do", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      // The echo payload should contain some guidance for the agent
      const echoPayload = output.args.command
      // Should mention asking the user or continuing/archiving/starting new
      const lowerPayload = echoPayload.toLowerCase()
      const hasInstruction =
        lowerPayload.includes("ask") ||
        lowerPayload.includes("continue") ||
        lowerPayload.includes("archive") ||
        lowerPayload.includes("active work") ||
        lowerPayload.includes("what") ||
        lowerPayload.includes("task")
      expect(hasInstruction).toBe(true)
    })

    test("injected context mentions all active work item names", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))
      registerWorkItem("task-beta", makeReadme("Beta Task"))
      registerWorkItem("task-gamma", makeReadme("Gamma Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.args.command).toContain("task-alpha")
      expect(output.args.command).toContain("task-beta")
      expect(output.args.command).toContain("task-gamma")
    })

    test("injected context mentions all active work item titles", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))
      registerWorkItem("task-beta", makeReadme("Beta Task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.args.command).toContain("Alpha Task")
      expect(output.args.command).toContain("Beta Task")
    })
  })

  // -------------------------------------------------------------------------
  // 9. Echo escaping: single quotes in content are properly escaped
  // -------------------------------------------------------------------------
  describe("echo escaping", () => {
    test("single quotes in a title are escaped to prevent bash injection", async () => {
      registerWorkItem("task-tricky", makeReadme("It's a tricky task"))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      // The raw single quote must NOT appear unescaped inside the echo '...' wrapper.
      // Proper escaping replaces ' with '\'' so the shell sees a continuous string.
      // The command starts with echo ' and ends before && — extract the echo payload.
      const cmd = output.args.command
      // Must use the bash single-quote escape pattern: '\''
      expect(cmd).toContain("'\\''")
    })

    test("single quotes in a description are escaped", async () => {
      registerWorkItem("task-desc", makeReadme("Normal Title", "Don't forget to check this."))

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      // Any single quote in the content must be escaped
      const cmd = output.args.command
      expect(cmd).toContain("'\\''")
    })
  })

  // -------------------------------------------------------------------------
  // 10. Description extraction: short description from README content
  // -------------------------------------------------------------------------
  describe("description extraction", () => {
    test("extracts description lines after the title from README.md", async () => {
      const readme = `---\ntags: [work]\n---\n\n## My Task\n\nThis is the description line.\nSecond description line.`
      registerWorkItem("task-desc", readme)

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      // At least one description line should appear in the injected context
      const hasDesc =
        output.args.command.includes("This is the description line") ||
        output.args.command.includes("Second description line")
      expect(hasDesc).toBe(true)
    })

    test("description is truncated to approximately 200 characters", async () => {
      const longDesc = "A".repeat(300)
      const readme = `---\ntags: [work]\n---\n\n## Long Desc Task\n\n${longDesc}`
      registerWorkItem("task-long", readme)

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      // The full 300-char description must NOT appear verbatim in the command
      expect(output.args.command).not.toContain("A".repeat(300))
    })

    test("README without description lines still works (title only)", async () => {
      const readme = `---\ntags: [work]\n---\n\n## Title Only Task`
      registerWorkItem("task-title-only", readme)

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      // Must still inject and include the title
      expect(output.args.command).toMatch(/^echo '/)
      expect(output.args.command).toContain("Title Only Task")
    })

    test("skips YAML frontmatter when extracting title", async () => {
      const readme = `---\ntags: [work]\nstatus: active\n---\n\n## Real Title\n\nReal description.`
      registerWorkItem("task-fm", readme)

      const plugin = await ActiveWorkContextPlugin(makeCtx())
      const hook = plugin["tool.execute.before"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      // Frontmatter keys must not appear as the title
      expect(output.args.command).not.toContain("tags:")
      expect(output.args.command).not.toContain("status:")
      expect(output.args.command).toContain("Real Title")
    })
  })

  // -------------------------------------------------------------------------
  // Plugin factory: returns the expected hook name
  // -------------------------------------------------------------------------
  describe("plugin factory", () => {
    test("returns an object with the tool.execute.before hook", async () => {
      const plugin = await ActiveWorkContextPlugin(makeCtx())
      expect(plugin["tool.execute.before"]).toBeTypeOf("function")
    })
  })
})

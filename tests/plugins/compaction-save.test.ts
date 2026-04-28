/**
 * Unit tests for the CompactionSavePlugin.
 *
 * Architecture note on Bun module caching:
 *   Bun caches ES modules after the first import. The fs mock must be set up
 *   BEFORE the first import of compaction-save.js. Because the plugin reads
 *   the filesystem inside the hook body (not at module load time), we can
 *   control behaviour per-test by swapping the module-level spy variables.
 *
 *   Strategy:
 *     - Set up the fs mock once at the top with spy variables.
 *     - Reset spy state before each test via the module-level variables.
 *     - Import the plugin AFTER the mock is in place.
 */

import { describe, test, expect, mock, beforeEach } from "bun:test"

// ---------------------------------------------------------------------------
// fs mock — must be set up BEFORE the first import of compaction-save.js
// ---------------------------------------------------------------------------

/** Tracks all writeFileSync calls: [path, content] pairs. */
let _writeCalls: Array<[string, string]> = []

/** Controls what readdirSync returns for a given path. */
const _readdirMap: Map<string, string[]> = new Map()

/** Controls what existsSync returns for a given path. */
const _existsMap: Map<string, boolean> = new Map()

/** Controls what readFileSync returns for a given path. */
const _readMap: Map<string, string> = new Map()

mock.module("fs", () => ({
  writeFileSync: (path: string, content: string) => {
    _writeCalls.push([path, content])
  },
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
  mkdirSync: (_path: string, _opts?: unknown) => {
    // no-op in tests
  },
}))

// ---------------------------------------------------------------------------
// Now import the plugin under test (after mocks are in place)
// ---------------------------------------------------------------------------
import { CompactionSavePlugin } from "../../src/plugins/compaction-save.js"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const TEST_DIR = "/test-project"
const ACTIVE_DIR = `${TEST_DIR}/.ai/telamon/memory/work/active`

/** Build a minimal plugin context. */
function makeCtx(directory = TEST_DIR) {
  return { directory } as Parameters<typeof CompactionSavePlugin>[0]
}

/** Build the compacting hook input/output pair. */
function makeHookArgs() {
  const input = {}
  const output: { context: string[]; prompt: string } = { context: [], prompt: "" }
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

/** Minimal README with frontmatter and a title line. */
function makeReadme(title: string) {
  return `---\ntags: [work]\n---\n\n## ${title}\n\nSome task description.`
}

// ---------------------------------------------------------------------------
// Reset state before each test
// ---------------------------------------------------------------------------

beforeEach(() => {
  _writeCalls = []
  _readdirMap.clear()
  _existsMap.clear()
  _readMap.clear()
})

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("CompactionSavePlugin", () => {

  // -------------------------------------------------------------------------
  // 1. Happy path: active work items with README.md → writes compaction.md
  // -------------------------------------------------------------------------
  describe("happy path", () => {
    test("writes compaction.md to each active work item that has a README.md", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))
      registerWorkItem("task-beta", makeReadme("Beta Task"))

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      const writtenPaths = _writeCalls.map(([p]) => p)
      expect(writtenPaths).toContain(`${ACTIVE_DIR}/task-alpha/compaction.md`)
      expect(writtenPaths).toContain(`${ACTIVE_DIR}/task-beta/compaction.md`)
    })

    test("populates output.context with a summary entry for each active work item", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))
      registerWorkItem("task-beta", makeReadme("Beta Task"))

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.context.length).toBeGreaterThan(0)
      expect(output.context.join("\n")).toContain("Alpha Task")
    })

    test("output.context entry mentions the active work item name", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      const combined = output.context.join("\n")
      expect(combined).toContain("task-alpha")
    })
  })

  // -------------------------------------------------------------------------
  // 2. No active work: work/active/ directory doesn't exist
  // -------------------------------------------------------------------------
  describe("no active work directory", () => {
    test("does not write any files when work/active/ does not exist", async () => {
      // _existsMap has no entry for ACTIVE_DIR → existsSync returns false

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(_writeCalls).toHaveLength(0)
    })

    test("leaves output.context unchanged when work/active/ does not exist", async () => {
      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.context).toHaveLength(0)
    })
  })

  // -------------------------------------------------------------------------
  // 3. Empty active directory: exists but has no subdirectories
  // -------------------------------------------------------------------------
  describe("empty active directory", () => {
    test("does not write any files when work/active/ has no subdirectories", async () => {
      _existsMap.set(ACTIVE_DIR, true)
      _readdirMap.set(ACTIVE_DIR, []) // empty listing

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(_writeCalls).toHaveLength(0)
    })

    test("leaves output.context unchanged when work/active/ has no subdirectories", async () => {
      _existsMap.set(ACTIVE_DIR, true)
      _readdirMap.set(ACTIVE_DIR, [])

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.context).toHaveLength(0)
    })
  })

  // -------------------------------------------------------------------------
  // 4. Subdirectory without README.md → should be skipped
  // -------------------------------------------------------------------------
  describe("subdirectory without README.md", () => {
    test("does not write compaction.md for a subdirectory that has no README.md", async () => {
      registerWorkItemNoReadme("task-no-readme")

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      const writtenPaths = _writeCalls.map(([p]) => p)
      expect(writtenPaths).not.toContain(`${ACTIVE_DIR}/task-no-readme/compaction.md`)
    })

    test("does not add a context entry for a subdirectory without README.md", async () => {
      registerWorkItemNoReadme("task-no-readme")

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      expect(output.context).toHaveLength(0)
    })
  })

  // -------------------------------------------------------------------------
  // 5. Mixed: some subdirectories have README.md, some don't
  // -------------------------------------------------------------------------
  describe("mixed subdirectories", () => {
    test("writes compaction.md only to subdirectories that have README.md", async () => {
      registerWorkItem("task-with-readme", makeReadme("Has Readme"))
      registerWorkItemNoReadme("task-without-readme")

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      const writtenPaths = _writeCalls.map(([p]) => p)
      expect(writtenPaths).toContain(`${ACTIVE_DIR}/task-with-readme/compaction.md`)
      expect(writtenPaths).not.toContain(`${ACTIVE_DIR}/task-without-readme/compaction.md`)
    })

    test("output.context has exactly one entry for the item with README.md", async () => {
      registerWorkItem("task-with-readme", makeReadme("Has Readme"))
      registerWorkItemNoReadme("task-without-readme")

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      // At least one context entry, and none should mention the no-readme item
      expect(output.context.length).toBeGreaterThan(0)
      const combined = output.context.join("\n")
      expect(combined).not.toContain("task-without-readme")
    })
  })

  // -------------------------------------------------------------------------
  // 6. Overwrite: compaction.md already exists → should be overwritten
  // -------------------------------------------------------------------------
  describe("overwrite existing compaction.md", () => {
    test("overwrites an existing compaction.md (writeFileSync is called again)", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      // Simulate an existing compaction.md
      const compactionPath = `${ACTIVE_DIR}/task-alpha/compaction.md`
      _existsMap.set(compactionPath, true)
      _readMap.set(compactionPath, "---\ncompacted_at: 2025-01-01T00:00:00.000Z\n---\nOld compaction.")

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      // writeFileSync must have been called for the compaction path
      const writtenPaths = _writeCalls.map(([p]) => p)
      expect(writtenPaths).toContain(compactionPath)
    })
  })

  // -------------------------------------------------------------------------
  // 7. compaction.md content: frontmatter + body mentioning "compaction"
  // -------------------------------------------------------------------------
  describe("compaction.md content format", () => {
    test("written content contains a YAML frontmatter block", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      const compactionPath = `${ACTIVE_DIR}/task-alpha/compaction.md`
      const call = _writeCalls.find(([p]) => p === compactionPath)
      expect(call).toBeDefined()

      const content = call![1]
      // Must open and close frontmatter
      expect(content).toMatch(/^---\n/)
      expect(content).toContain("---")
    })

    test("frontmatter contains a compacted_at field with an ISO timestamp", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      const compactionPath = `${ACTIVE_DIR}/task-alpha/compaction.md`
      const call = _writeCalls.find(([p]) => p === compactionPath)
      expect(call).toBeDefined()

      const content = call![1]
      // compacted_at must be present and look like an ISO timestamp
      expect(content).toMatch(/compacted_at:\s*\d{4}-\d{2}-\d{2}T[\d:.]+Z/)
    })

    test("body text mentions 'compaction'", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      const compactionPath = `${ACTIVE_DIR}/task-alpha/compaction.md`
      const call = _writeCalls.find(([p]) => p === compactionPath)
      expect(call).toBeDefined()

      const content = call![1]
      expect(content.toLowerCase()).toContain("compaction")
      expect(content).toContain("Alpha Task")
    })

    test("compacted_at timestamp is recent (within 5 seconds of now)", async () => {
      registerWorkItem("task-alpha", makeReadme("Alpha Task"))

      const before = Date.now()

      const plugin = await CompactionSavePlugin(makeCtx())
      const hook = plugin["experimental.session.compacting"]!
      const { input, output } = makeHookArgs()

      await hook(input, output)

      const after = Date.now()

      const compactionPath = `${ACTIVE_DIR}/task-alpha/compaction.md`
      const call = _writeCalls.find(([p]) => p === compactionPath)
      expect(call).toBeDefined()

      const content = call![1]
      const match = content.match(/compacted_at:\s*(\S+)/)
      expect(match).toBeDefined()

      const ts = new Date(match![1]).getTime()
      expect(ts).toBeGreaterThanOrEqual(before)
      expect(ts).toBeLessThanOrEqual(after + 5000)
    })
  })

  // -------------------------------------------------------------------------
  // 8. Plugin factory: returns the expected hook name
  // -------------------------------------------------------------------------
  describe("plugin factory", () => {
    test("returns an object with the experimental.session.compacting hook", async () => {
      const plugin = await CompactionSavePlugin(makeCtx())
      expect(plugin["experimental.session.compacting"]).toBeTypeOf("function")
    })
  })
})

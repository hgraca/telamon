/**
 * Unit tests for src/plugins/graphify.js — GraphifyPlugin
 *
 * Strategy: graphify.js uses `import { readFileSync, existsSync } from "fs"` —
 * ESM static named imports are bound at module load time in Bun, making
 * mock.module("fs") unreliable for intercepting them after the fact.
 *
 * We use real temporary files instead, writing GRAPH_REPORT.md content to
 * a temp directory and passing that directory to GraphifyPlugin.
 *
 * This tests the full observable behavior: does the plugin inject context
 * into bash commands, and does it extract the right sections?
 */

import { describe, test, expect } from "bun:test"
import { mkdirSync, writeFileSync, rmSync } from "fs"
import { join } from "path"
import { GraphifyPlugin } from "../../src/plugins/graphify.js"

// ---------------------------------------------------------------------------
// Temp directory helpers
// ---------------------------------------------------------------------------

let _tmpCounter = 0

function makeTmpDir(): string {
  const dir = join("/tmp", `graphify-test-${process.pid}-${++_tmpCounter}`)
  mkdirSync(join(dir, "graphify-out"), { recursive: true })
  return dir
}

function writeReport(dir: string, content: string): void {
  writeFileSync(join(dir, "graphify-out", "GRAPH_REPORT.md"), content, "utf8")
}

function cleanTmpDir(dir: string): void {
  try { rmSync(dir, { recursive: true, force: true }) } catch { /* ignore */ }
}

// ---------------------------------------------------------------------------
// Sample GRAPH_REPORT.md content
// ---------------------------------------------------------------------------

const FULL_REPORT = `
# Knowledge Graph Report

## God Nodes

- **UserRepository** (12 edges)
- **CommandBus** (10 edges)
- **EventDispatcher** (8 edges)
- **QueryBus** (7 edges)
- **DomainEvent** (6 edges)
- **ExtraNode** (5 edges)

---

## Communities

### Core Domain
Some description.

### Application Layer
Another description.

### Infrastructure
Details here.

---

## Surprising Connections

- **UserRepository** --calls--> **EventDispatcher** [INFERRED]
- **CommandBus** --uses--> **QueryBus** [UNEXPECTED]
- **DomainEvent** --triggers--> **CommandBus** [INFERRED]
- **ExtraConnection** (should be excluded)

---
`

const GOD_NODES_ONLY_REPORT = `
## God Nodes

- NodeA (5 edges)
- NodeB (4 edges)

---
`

const COMMUNITIES_ONLY_REPORT = `
## Communities

### Alpha Community
Description.

### Beta Community
Description.

---
`

const SURPRISING_ONLY_REPORT = `
## Surprising Connections

- **A** --calls--> **B** [INFERRED]
- **C** --uses--> **D** [UNEXPECTED]

---
`

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build a before-hook input/output pair for a bash command. */
function makeBeforeArgs(command = "ls") {
  const input = { tool: "bash", sessionID: "s1", callID: "c1" }
  const output = { args: { command } }
  return { input, output }
}

/** Run the plugin's before hook once and return the rewritten command. */
async function runBefore(dir: string, command = "ls"): Promise<string> {
  const hooks = await GraphifyPlugin({ directory: dir })
  const before = hooks["tool.execute.before"]!
  const { input, output } = makeBeforeArgs(command)
  await before(input, output)
  return String((output.args as Record<string, unknown>).command)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("GraphifyPlugin", () => {

  // -------------------------------------------------------------------------
  // 1. Report file missing
  // -------------------------------------------------------------------------
  describe("when GRAPH_REPORT.md does not exist", () => {
    test("does not inject context (command unchanged)", async () => {
      const dir = makeTmpDir()
      try {
        // Don't write the report file — directory exists but no GRAPH_REPORT.md
        const cmd = await runBefore(dir, "ls -la")
        expect(cmd).toBe("ls -la")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("does not inject when graphify-out directory doesn't exist", async () => {
      const dir = join("/tmp", `graphify-test-nodir-${process.pid}`)
      mkdirSync(dir, { recursive: true })
      try {
        const cmd = await runBefore(dir, "pwd")
        expect(cmd).toBe("pwd")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  // -------------------------------------------------------------------------
  // 2. Report exists but empty / no recognised sections
  // -------------------------------------------------------------------------
  describe("when report has no recognised sections", () => {
    test("does not inject context (command unchanged)", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, "# Just a title\n\nNo sections here.\n")
        const cmd = await runBefore(dir)
        expect(cmd).toBe("ls")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  // -------------------------------------------------------------------------
  // 3. God Nodes extraction
  // -------------------------------------------------------------------------
  describe("God Nodes section", () => {
    test("injects [graphify] prefix when god nodes present", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, GOD_NODES_ONLY_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("[graphify]")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("includes 'God Nodes (most connected):' label", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, GOD_NODES_ONLY_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("God Nodes (most connected):")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("extracts node names from bullet list", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, GOD_NODES_ONLY_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("NodeA")
        expect(cmd).toContain("NodeB")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("limits god nodes to top 5", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, FULL_REPORT)
        const cmd = await runBefore(dir)
        // FULL_REPORT has 6 nodes — ExtraNode should be excluded
        expect(cmd).not.toContain("ExtraNode")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("strips ** bold markers from node names", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, "## God Nodes\n\n- **BoldNode** (10 edges)\n\n---\n")
        const cmd = await runBefore(dir)
        expect(cmd).toContain("BoldNode")
        expect(cmd).not.toContain("**")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("strips leading - bullet markers", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, GOD_NODES_ONLY_REPORT)
        const cmd = await runBefore(dir)
        // Should not have raw "- " in the god nodes list
        const godPart = cmd.split("God Nodes (most connected):")[1]?.split("\n")[0] ?? ""
        expect(godPart).not.toMatch(/^- /)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  // -------------------------------------------------------------------------
  // 4. Communities extraction
  // -------------------------------------------------------------------------
  describe("Communities section", () => {
    test("injects [graphify] prefix when communities present", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, COMMUNITIES_ONLY_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("[graphify]")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("includes 'Communities:' label", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, COMMUNITIES_ONLY_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("Communities:")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("extracts ### community names", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, COMMUNITIES_ONLY_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("Alpha Community")
        expect(cmd).toContain("Beta Community")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("extracts **bold** community names", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, "## Communities\n\n**Core Domain**\nDescription.\n\n---\n")
        const cmd = await runBefore(dir)
        expect(cmd).toContain("Core Domain")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("extracts numbered community names (N: Name format)", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, "## Communities\n\n1. First Community\n2. Second Community\n\n---\n")
        const cmd = await runBefore(dir)
        expect(cmd).toContain("First Community")
        expect(cmd).toContain("Second Community")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("limits communities to 10", async () => {
      const dir = makeTmpDir()
      try {
        const lines = Array.from({ length: 15 }, (_, i) => `### Community ${i + 1}`).join("\n")
        writeReport(dir, `## Communities\n\n${lines}\n\n---\n`)
        const cmd = await runBefore(dir)
        // Community 11 through 15 should be excluded
        expect(cmd).not.toContain("Community 11")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  // -------------------------------------------------------------------------
  // 5. Surprising Connections extraction
  // -------------------------------------------------------------------------
  describe("Surprising Connections section", () => {
    test("injects [graphify] prefix when surprising connections present", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, SURPRISING_ONLY_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("[graphify]")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("includes 'Surprising Connections:' label", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, SURPRISING_ONLY_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("Surprising Connections:")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("extracts connection descriptions", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, SURPRISING_ONLY_REPORT)
        const cmd = await runBefore(dir)
        // Connection content should appear (bold markers stripped)
        expect(cmd).toContain("A")
        expect(cmd).toContain("B")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("limits surprising connections to top 3", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, FULL_REPORT)
        const cmd = await runBefore(dir)
        // FULL_REPORT has 4 connections — ExtraConnection should be excluded
        expect(cmd).not.toContain("ExtraConnection")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("strips ** bold markers from connections", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, SURPRISING_ONLY_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).not.toContain("**")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("joins connections with semicolon separator", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, SURPRISING_ONLY_REPORT)
        const cmd = await runBefore(dir)
        const surprisePart = cmd.split("Surprising Connections:")[1] ?? ""
        // Two connections → one semicolon
        expect(surprisePart).toContain(";")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  // -------------------------------------------------------------------------
  // 6. Full report — all sections present
  // -------------------------------------------------------------------------
  describe("full report with all sections", () => {
    test("injects all three sections", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, FULL_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("God Nodes (most connected):")
        expect(cmd).toContain("Communities:")
        expect(cmd).toContain("Surprising Connections:")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("prepends echo before original command", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, FULL_REPORT)
        const cmd = await runBefore(dir, "git status")
        expect(cmd).toMatch(/^echo '/)
        expect(cmd).toContain("&& git status")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("output starts with [graphify] Knowledge graph context:", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, FULL_REPORT)
        const cmd = await runBefore(dir)
        expect(cmd).toContain("[graphify] Knowledge graph context:")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  // -------------------------------------------------------------------------
  // 7. Injection is one-shot (only first bash call)
  // -------------------------------------------------------------------------
  describe("one-shot injection", () => {
    test("injects on first bash call only", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, GOD_NODES_ONLY_REPORT)
        const hooks = await GraphifyPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!

        // First call — should inject
        const { input: i1, output: o1 } = makeBeforeArgs("ls")
        await before(i1, o1)
        expect(String((o1.args as Record<string, unknown>).command)).toContain("[graphify]")

        // Second call — should NOT inject again
        const { input: i2, output: o2 } = makeBeforeArgs("pwd")
        await before(i2, o2)
        expect(String((o2.args as Record<string, unknown>).command)).toBe("pwd")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("does not inject on non-bash tool calls", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, GOD_NODES_ONLY_REPORT)
        const hooks = await GraphifyPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!

        const input = { tool: "edit", sessionID: "s1", callID: "c1" }
        const output = { args: { command: "some-edit" } }
        await before(input, output)
        expect(String((output.args as Record<string, unknown>).command)).toBe("some-edit")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("after non-bash call, first bash call still injects", async () => {
      const dir = makeTmpDir()
      try {
        writeReport(dir, GOD_NODES_ONLY_REPORT)
        const hooks = await GraphifyPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!

        // Non-bash first
        await before({ tool: "read", sessionID: "s", callID: "c" }, { args: { command: "x" } })

        // First bash — should still inject (injected flag not set by non-bash)
        const { input, output } = makeBeforeArgs("ls")
        await before(input, output)
        expect(String((output.args as Record<string, unknown>).command)).toContain("[graphify]")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  // -------------------------------------------------------------------------
  // 8. Path construction
  // -------------------------------------------------------------------------
  describe("report path construction", () => {
    test("looks for report in <directory>/graphify-out/GRAPH_REPORT.md", async () => {
      const dir = makeTmpDir()
      try {
        // Write report at the expected path
        writeReport(dir, GOD_NODES_ONLY_REPORT)
        const cmd = await runBefore(dir)
        // If the path is correct, injection happens
        expect(cmd).toContain("[graphify]")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("does not inject when report is at wrong path", async () => {
      const dir = makeTmpDir()
      try {
        // Write at wrong location (not in graphify-out/)
        writeFileSync(join(dir, "GRAPH_REPORT.md"), GOD_NODES_ONLY_REPORT, "utf8")
        const cmd = await runBefore(dir)
        // Should NOT inject — wrong path
        expect(cmd).toBe("ls")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })
})

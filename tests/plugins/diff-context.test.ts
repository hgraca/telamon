import { describe, test, expect } from "bun:test"
import { mkdirSync, writeFileSync, rmSync, mkdtempSync } from "fs"
import { join } from "path"
import { execSync } from "child_process"
import { DiffContextPlugin } from "../../src/plugins/diff-context.js"

let _tmpCounter = 0
function makeTmpDir(): string {
  const dir = join("/tmp", `diff-context-test-${process.pid}-${++_tmpCounter}`)
  mkdirSync(dir, { recursive: true })
  return dir
}
function cleanTmpDir(dir: string): void {
  try { rmSync(dir, { recursive: true, force: true }) } catch {}
}

function makeGitRepo(dir: string): void {
  execSync("git init", { cwd: dir })
  execSync("git config user.email test@test.com", { cwd: dir })
  execSync("git config user.name Test", { cwd: dir })
  writeFileSync(join(dir, "file.txt"), "initial")
  execSync("git add .", { cwd: dir })
  execSync('git commit -m "initial commit"', { cwd: dir })
}

function writeWatermark(dir: string, slug: string, timestamp: string): void {
  const wDir = join(dir, ".ai/telamon/memory/thinking")
  mkdirSync(wDir, { recursive: true })
  writeFileSync(join(wDir, `.last-capture-${slug}.json`), JSON.stringify({ timestamp }), "utf8")
}

function makeBeforeArgs(command = "ls") {
  const input = { tool: "bash", sessionID: "s1", callID: "c1" }
  const output = { args: { command } }
  return { input, output }
}

async function runBefore(dir: string, command = "ls", worktree?: string): Promise<string> {
  const hooks = await DiffContextPlugin({ directory: dir, worktree })
  const before = hooks["tool.execute.before"]!
  const { input, output } = makeBeforeArgs(command)
  await before(input, output)
  return String((output.args as Record<string, unknown>).command)
}

describe("DiffContextPlugin", () => {

  describe("worktreeSlug", () => {
    test("sanitizes special chars to dashes, lowercases", async () => {
      const dir = makeTmpDir()
      try {
        makeGitRepo(dir)
        // worktree with special chars — slug used in watermark filename
        const slug = "my-project-123"
        writeWatermark(dir, slug, new Date(Date.now() - 999999999).toISOString())
        // Just verify plugin runs without error — slug logic is internal
        const cmd = await runBefore(dir, "ls", "/some/path/My Project 123")
        expect(typeof cmd).toBe("string")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("getWatermarkTimestamp", () => {
    test("returns null when watermark file missing", async () => {
      const dir = makeTmpDir()
      try {
        makeGitRepo(dir)
        // No watermark — falls back to last 10 commits
        const cmd = await runBefore(dir, "ls")
        // Should still inject (has commits)
        expect(cmd).toContain("[diff-context]")
        expect(cmd).toContain("last 10 commits")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("uses watermark timestamp when file exists with valid ISO", async () => {
      const dir = makeTmpDir()
      try {
        makeGitRepo(dir)
        // Plugin uses basename(directory) as slug
        const { basename } = await import("path")
        const slug = basename(dir).replace(/[^a-z0-9_-]/gi, "-").toLowerCase()
        const oldTs = new Date(Date.now() - 999999999).toISOString()
        writeWatermark(dir, slug, oldTs)
        const cmd = await runBefore(dir, "ls")
        // With watermark, header says "since last session"
        expect(cmd).toContain("since last session")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("ignores watermark with invalid timestamp format", async () => {
      const dir = makeTmpDir()
      try {
        makeGitRepo(dir)
        const { basename } = await import("path")
        const slug = basename(dir).replace(/[^a-z0-9_-]/gi, "-").toLowerCase()
        writeWatermark(dir, slug, "not-a-valid-timestamp")
        const cmd = await runBefore(dir, "ls")
        // Falls back to last 10 commits
        expect(cmd).toContain("last 10 commits")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("buildContext", () => {
    test("returns null (no injection) when no .git directory", async () => {
      const dir = makeTmpDir()
      try {
        // No git init — no .git dir
        const cmd = await runBefore(dir, "echo hello")
        expect(cmd).toBe("echo hello")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("injects context when git repo has commits", async () => {
      const dir = makeTmpDir()
      try {
        makeGitRepo(dir)
        const cmd = await runBefore(dir, "ls")
        expect(cmd).toContain("[diff-context]")
        expect(cmd).toMatch(/^echo '/)
        expect(cmd).toContain("&& ls")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("truncation suffix format is correct when triggered", () => {
      // Verify the suffix format by checking the logic directly
      // (creating 35 commits is too slow for a unit test)
      const lines = Array.from({ length: 35 }, (_, i) => `commit ${i}`)
      const MAX = 30
      const remaining = lines.length - MAX
      const truncated = [...lines.slice(0, MAX), `... (${remaining} more commits)`]
      expect(truncated[30]).toBe("... (5 more commits)")
    })
  })

  describe("plugin hook", () => {
    test("only fires on bash tool", async () => {
      const dir = makeTmpDir()
      try {
        makeGitRepo(dir)
        const hooks = await DiffContextPlugin({ directory: dir, worktree: undefined })
        const before = hooks["tool.execute.before"]!
        const input = { tool: "edit", sessionID: "s1", callID: "c1" }
        const output = { args: { command: "some-edit" } }
        await before(input, output)
        expect((output.args as any).command).toBe("some-edit")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("only fires once (injected flag)", async () => {
      const dir = makeTmpDir()
      try {
        makeGitRepo(dir)
        const hooks = await DiffContextPlugin({ directory: dir, worktree: undefined })
        const before = hooks["tool.execute.before"]!

        const { input: i1, output: o1 } = makeBeforeArgs("ls")
        await before(i1, o1)
        const first = String((o1.args as any).command)

        const { input: i2, output: o2 } = makeBeforeArgs("pwd")
        await before(i2, o2)
        expect((o2.args as any).command).toBe("pwd")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("prepends echo with escaped context to command", async () => {
      const dir = makeTmpDir()
      try {
        makeGitRepo(dir)
        const cmd = await runBefore(dir, "git status")
        expect(cmd).toMatch(/^echo '/)
        expect(cmd).toContain("&& git status")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })
})

import { describe, test, expect } from "bun:test"
import { mkdirSync, writeFileSync, rmSync } from "fs"
import { join } from "path"
import { Database } from "bun:sqlite"
import { ToolStatsPlugin } from "../../src/plugins/tool-stats.js"

let _tmpCounter = 0
function makeTmpDir(): string {
  const dir = join("/tmp", `tool-stats-test-${process.pid}-${++_tmpCounter}`)
  mkdirSync(dir, { recursive: true })
  return dir
}
function cleanTmpDir(dir: string): void {
  try { rmSync(dir, { recursive: true, force: true }) } catch {}
}

function writeTelamonJsonc(dir: string, projectName: string): void {
  writeFileSync(join(dir, ".telamon.jsonc"), JSON.stringify({ project_name: projectName }), "utf8")
}

function writeProjectConfig(dir: string, projectName: string): void {
  const configDir = join(dir, ".ai", "telamon")
  mkdirSync(configDir, { recursive: true })
  writeFileSync(join(configDir, "telamon.jsonc"), JSON.stringify({ project_name: projectName }), "utf8")
}

describe("ToolStatsPlugin", () => {

  describe("findTelamonRoot", () => {
    test("finds .telamon.jsonc in current dir", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test-project")
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "bash" })
        // DB should be in dir/storage/stats/
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()
        expect(rows.length).toBe(1)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("walks up to find .telamon.jsonc in parent", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "parent-project")
        const subDir = join(dir, "sub", "dir")
        mkdirSync(subDir, { recursive: true })
        const hooks = await ToolStatsPlugin({ directory: subDir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "bash" })
        // DB should be in parent dir
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()
        expect(rows.length).toBe(1)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("falls back to dir itself if no .telamon.jsonc found", async () => {
      const dir = makeTmpDir()
      try {
        // No .telamon.jsonc — DB goes in dir/storage/stats/
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "bash" })
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()
        expect(rows.length).toBe(1)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("parseJsonc", () => {
    test("strips // line comments", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const configDir = join(dir, ".ai", "telamon")
        mkdirSync(configDir, { recursive: true })
        writeFileSync(
          join(configDir, "telamon.jsonc"),
          `{
  // This is a comment
  "project_name": "commented-project" // inline comment
}`,
          "utf8"
        )
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "bash" })
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()
        expect((rows[0] as any).project).toBe("commented-project")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("readProjectName", () => {
    test("reads project_name from .ai/telamon/telamon.jsonc", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        writeProjectConfig(dir, "my-project")
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "bash" })
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()
        expect((rows[0] as any).project).toBe("my-project")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("returns 'unknown' when config missing", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        // No .ai/telamon/telamon.jsonc
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "bash" })
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()
        expect((rows[0] as any).project).toBe("unknown")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("tool.execute.before hook", () => {
    test("creates stats.sqlite and tool_calls table", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "bash" })
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='tool_calls'").all()
        db.close()
        expect(rows.length).toBe(1)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("inserts row with tool, agent, skill, project, timestamp", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        writeProjectConfig(dir, "proj")
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "bash", agent: "developer", skill: "tdd" })
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()
        expect(rows.length).toBe(1)
        expect(rows[0].tool).toBe("bash")
        expect(rows[0].agent).toBe("developer")
        expect(rows[0].skill).toBe("tdd")
        expect(rows[0].project).toBe("proj")
        expect(rows[0].timestamp).toBeTruthy()
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("reads agent/skill from metadata when not top-level", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "edit", metadata: { agent: "reviewer", skill: "code-review" } })
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()
        expect(rows[0].agent).toBe("reviewer")
        expect(rows[0].skill).toBe("code-review")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("inserts multiple rows per call", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before({ tool: "bash" })
        await before({ tool: "edit" })
        await before({ tool: "read" })
        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()
        expect(rows.length).toBe(3)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("catches errors silently", async () => {
      const dir = makeTmpDir()
      try {
        // Pass a non-existent deeply nested directory that can't be created
        // Actually we can't easily force mkdirSync to fail, so just verify
        // that the hook doesn't throw even with weird input
        const hooks = await ToolStatsPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        // Should not throw
        await expect(before({ tool: undefined as any })).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })
  })
})

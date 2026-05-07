import { describe, test, expect, mock, beforeEach, afterEach } from "bun:test"
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

  // ─── New tests: agent/skill derived from session messages ─────────────────

  describe("agent derivation from session messages", () => {

    function makeClient(messages: any[]) {
      return {
        session: {
          messages: mock(async (_opts: any) => ({ data: messages })),
        },
      }
    }

    function makeAssistantMessage(agent: string) {
      return { info: { role: "assistant", agent } }
    }

    test("agent cache hit: uses cached agent without re-fetching", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const client = makeClient([makeAssistantMessage("developer")])
        const hooks = await ToolStatsPlugin({ directory: dir, client })
        const before = hooks["tool.execute.before"]!

        // First call — populates cache
        await before({ tool: "bash", sessionID: "sess-1" })
        // Second call — should hit cache, not re-fetch
        await before({ tool: "edit", sessionID: "sess-1" })

        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls ORDER BY id").all() as any[]
        db.close()

        expect(rows.length).toBe(2)
        expect(rows[0].agent).toBe("developer")
        expect(rows[1].agent).toBe("developer")
        // messages fetched only once (cache hit on second call)
        expect((client.session.messages as ReturnType<typeof mock>).mock.calls.length).toBe(1)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("agent cache miss: fetches messages, extracts agent from last assistant message, caches it", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const client = makeClient([
          { info: { role: "user" } },
          makeAssistantMessage("tester"),
        ])
        const hooks = await ToolStatsPlugin({ directory: dir, client })
        const before = hooks["tool.execute.before"]!

        await before({ tool: "bash", sessionID: "sess-fresh" })

        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()

        expect(rows.length).toBe(1)
        expect(rows[0].agent).toBe("tester")
        expect((client.session.messages as ReturnType<typeof mock>).mock.calls.length).toBe(1)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("agent cache TTL expiry: refetches after 60s", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const client = makeClient([makeAssistantMessage("developer")])
        // Inject a clock that starts at 0 and can be advanced
        let now = 0
        const hooks = await ToolStatsPlugin({ directory: dir, client, _now: () => now })
        const before = hooks["tool.execute.before"]!

        // First call at t=0 — fetches and caches
        await before({ tool: "bash", sessionID: "sess-ttl" })
        expect((client.session.messages as ReturnType<typeof mock>).mock.calls.length).toBe(1)

        // Second call at t=30s — still within TTL, no re-fetch
        now = 30_000
        await before({ tool: "edit", sessionID: "sess-ttl" })
        expect((client.session.messages as ReturnType<typeof mock>).mock.calls.length).toBe(1)

        // Third call at t=61s — TTL expired, re-fetch
        now = 61_000
        await before({ tool: "read", sessionID: "sess-ttl" })
        expect((client.session.messages as ReturnType<typeof mock>).mock.calls.length).toBe(2)

        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls ORDER BY id").all() as any[]
        db.close()
        expect(rows.length).toBe(3)
        expect(rows[2].agent).toBe("developer")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("agent fetch failure: row inserted with agent=null, error does not propagate", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const client = {
          session: {
            messages: mock(async (_opts: any) => { throw new Error("network error") }),
          },
        }
        const hooks = await ToolStatsPlugin({ directory: dir, client })
        const before = hooks["tool.execute.before"]!

        // Must not throw
        await expect(before({ tool: "bash", sessionID: "sess-fail" })).resolves.toBeUndefined()

        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()

        expect(rows.length).toBe(1)
        expect(rows[0].agent).toBeNull()
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("skill derivation from skill tool calls", () => {

    function makeClient() {
      return {
        session: {
          messages: mock(async (_opts: any) => ({ data: [] })),
        },
      }
    }

    test("skill tool call sets active skill; subsequent calls in same session use that skill", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const client = makeClient()
        const hooks = await ToolStatsPlugin({ directory: dir, client })
        const before = hooks["tool.execute.before"]!

        // skill tool call — should record skill="telamon.example" for THIS row too
        await before({ tool: "skill", sessionID: "sess-skill", args: { name: "telamon.example" } })
        // subsequent tool call — should inherit skill
        await before({ tool: "bash", sessionID: "sess-skill" })

        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls ORDER BY id").all() as any[]
        db.close()

        expect(rows.length).toBe(2)
        expect(rows[0].skill).toBe("telamon.example")
        expect(rows[1].skill).toBe("telamon.example")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("no skill loaded yet: row inserted with skill=null", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const client = makeClient()
        const hooks = await ToolStatsPlugin({ directory: dir, client })
        const before = hooks["tool.execute.before"]!

        await before({ tool: "bash", sessionID: "sess-noskill" })

        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls").all() as any[]
        db.close()

        expect(rows.length).toBe(1)
        expect(rows[0].skill).toBeNull()
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("new skill tool call replaces old active skill", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const client = makeClient()
        const hooks = await ToolStatsPlugin({ directory: dir, client })
        const before = hooks["tool.execute.before"]!

        await before({ tool: "skill", sessionID: "sess-replace", args: { name: "skill-one" } })
        await before({ tool: "bash", sessionID: "sess-replace" })
        await before({ tool: "skill", sessionID: "sess-replace", args: { name: "skill-two" } })
        await before({ tool: "edit", sessionID: "sess-replace" })

        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls ORDER BY id").all() as any[]
        db.close()

        expect(rows.length).toBe(4)
        expect(rows[0].skill).toBe("skill-one")
        expect(rows[1].skill).toBe("skill-one")
        expect(rows[2].skill).toBe("skill-two")
        expect(rows[3].skill).toBe("skill-two")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("skill is per-session: skill loaded in session A does not leak into session B", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, "test")
        const client = makeClient()
        const hooks = await ToolStatsPlugin({ directory: dir, client })
        const before = hooks["tool.execute.before"]!

        // Load skill in session A
        await before({ tool: "skill", sessionID: "sess-A", args: { name: "skill-a" } })
        await before({ tool: "bash", sessionID: "sess-A" })

        // Session B — no skill loaded
        await before({ tool: "bash", sessionID: "sess-B" })

        const db = new Database(join(dir, "storage", "stats", "stats.sqlite"))
        const rows = db.query("SELECT * FROM tool_calls ORDER BY id").all() as any[]
        db.close()

        expect(rows.length).toBe(3)
        expect(rows[0].skill).toBe("skill-a")  // sess-A skill call
        expect(rows[1].skill).toBe("skill-a")  // sess-A bash call
        expect(rows[2].skill).toBeNull()        // sess-B — no skill
      } finally {
        cleanTmpDir(dir)
      }
    })
  })
})

import { describe, test, expect } from "bun:test"
import { mkdirSync, writeFileSync, rmSync, readFileSync, existsSync } from "fs"
import { join } from "path"
import { SessionCapturePlugin } from "../../src/plugins/session-capture.js"

let _tmpCounter = 0
function makeTmpDir(): string {
  const dir = join("/tmp", `session-capture-test-${process.pid}-${++_tmpCounter}`)
  mkdirSync(dir, { recursive: true })
  return dir
}
function cleanTmpDir(dir: string): void {
  try { rmSync(dir, { recursive: true, force: true }) } catch {}
}

function watermarkPath(dir: string, slug: string): string {
  return join(dir, `.ai/telamon/memory/thinking/.last-capture-${slug}.json`)
}

function writeWatermark(dir: string, slug: string, timestamp: string): void {
  const wDir = join(dir, ".ai/telamon/memory/thinking")
  mkdirSync(wDir, { recursive: true })
  writeFileSync(watermarkPath(dir, slug), JSON.stringify({ timestamp }), "utf8")
}

function makeIdleEvent(sessionId = "test-session-123") {
  return { type: "session.idle", properties: { info: { id: sessionId } } }
}

function makeClient(onPrompt?: () => Promise<void>) {
  let called = false
  const client = {
    session: {
      prompt: async (...args: any[]) => {
        called = true
        if (onPrompt) await onPrompt()
      },
    },
    wasCalled: () => called,
  }
  return client
}

describe("SessionCapturePlugin", () => {

  describe("event type guard", () => {
    test("ignores non-session.idle events", async () => {
      const dir = makeTmpDir()
      try {
        const client = makeClient()
        const hooks = await SessionCapturePlugin({ directory: dir, worktree: undefined, client })
        const eventHook = hooks["event"]!
        await eventHook({ event: { type: "session.start", properties: { info: { id: "s1" } } } })
        expect(client.wasCalled()).toBe(false)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("ignores events without sessionId", async () => {
      const dir = makeTmpDir()
      try {
        const client = makeClient()
        const hooks = await SessionCapturePlugin({ directory: dir, worktree: undefined, client })
        const eventHook = hooks["event"]!
        await eventHook({ event: { type: "session.idle", properties: {} } })
        expect(client.wasCalled()).toBe(false)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("no watermark → fires", () => {
    test("calls client.session.prompt when no watermark exists", async () => {
      const dir = makeTmpDir()
      try {
        const client = makeClient()
        const hooks = await SessionCapturePlugin({ directory: dir, worktree: undefined, client })
        const eventHook = hooks["event"]!
        await eventHook({ event: makeIdleEvent() })
        expect(client.wasCalled()).toBe(true)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("recent watermark → throttled", () => {
    test("does NOT call prompt when watermark is < 30 min old", async () => {
      const dir = makeTmpDir()
      try {
        // Determine slug: basename of dir, sanitized
        const slug = dir.split("/").pop()!.replace(/[^a-z0-9_-]/gi, "-").toLowerCase()
        const recentTs = new Date(Date.now() - 5 * 60 * 1000).toISOString() // 5 min ago
        writeWatermark(dir, slug, recentTs)
        const client = makeClient()
        const hooks = await SessionCapturePlugin({ directory: dir, worktree: undefined, client })
        const eventHook = hooks["event"]!
        await eventHook({ event: makeIdleEvent() })
        expect(client.wasCalled()).toBe(false)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("old watermark → fires", () => {
    test("calls prompt when watermark is > 30 min old", async () => {
      const dir = makeTmpDir()
      try {
        const slug = dir.split("/").pop()!.replace(/[^a-z0-9_-]/gi, "-").toLowerCase()
        const oldTs = new Date(Date.now() - 60 * 60 * 1000).toISOString() // 60 min ago
        writeWatermark(dir, slug, oldTs)
        const client = makeClient()
        const hooks = await SessionCapturePlugin({ directory: dir, worktree: undefined, client })
        const eventHook = hooks["event"]!
        await eventHook({ event: makeIdleEvent() })
        expect(client.wasCalled()).toBe(true)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("watermark written before prompt", () => {
    test("watermark file exists with new timestamp before prompt fires", async () => {
      const dir = makeTmpDir()
      try {
        const slug = dir.split("/").pop()!.replace(/[^a-z0-9_-]/gi, "-").toLowerCase()
        const wPath = watermarkPath(dir, slug)
        let watermarkExistedBeforePrompt = false
        const client = makeClient(async () => {
          watermarkExistedBeforePrompt = existsSync(wPath)
        })
        const hooks = await SessionCapturePlugin({ directory: dir, worktree: undefined, client })
        const eventHook = hooks["event"]!
        await eventHook({ event: makeIdleEvent() })
        expect(watermarkExistedBeforePrompt).toBe(true)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("failed prompt → watermark rolled back", () => {
    test("restores old watermark when prompt throws", async () => {
      const dir = makeTmpDir()
      try {
        const slug = dir.split("/").pop()!.replace(/[^a-z0-9_-]/gi, "-").toLowerCase()
        const oldTs = new Date(Date.now() - 60 * 60 * 1000).toISOString()
        writeWatermark(dir, slug, oldTs)
        const client = makeClient(async () => { throw new Error("network error") })
        const hooks = await SessionCapturePlugin({ directory: dir, worktree: undefined, client })
        const eventHook = hooks["event"]!
        await eventHook({ event: makeIdleEvent() })
        // Watermark should be rolled back to old timestamp
        const wPath = watermarkPath(dir, slug)
        const data = JSON.parse(readFileSync(wPath, "utf8"))
        expect(data.timestamp).toBe(oldTs)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("does not crash when prompt throws and no prior watermark", async () => {
      const dir = makeTmpDir()
      try {
        const client = makeClient(async () => { throw new Error("fail") })
        const hooks = await SessionCapturePlugin({ directory: dir, worktree: undefined, client })
        const eventHook = hooks["event"]!
        // Should not throw
        await expect(eventHook({ event: makeIdleEvent() })).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("worktree slug", () => {
    test("uses worktree basename for slug when provided", async () => {
      const dir = makeTmpDir()
      try {
        const worktree = "/some/path/My Worktree 123"
        const expectedSlug = "my-worktree-123"
        const client = makeClient()
        const hooks = await SessionCapturePlugin({ directory: dir, worktree, client })
        const eventHook = hooks["event"]!
        await eventHook({ event: makeIdleEvent() })
        // Watermark should be at slug-based path
        const wPath = watermarkPath(dir, expectedSlug)
        expect(existsSync(wPath)).toBe(true)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })
})

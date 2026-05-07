import { describe, test, expect } from "bun:test"
import { mkdirSync, writeFileSync, rmSync, existsSync } from "fs"
import { join, basename } from "path"
import { RememberSessionPlugin } from "../../src/plugins/remember-session.js"

let _tmpCounter = 0
function makeTmpDir(): string {
  const dir = join("/tmp", `remember-session-test-${process.pid}-${++_tmpCounter}`)
  mkdirSync(dir, { recursive: true })
  return dir
}
function cleanTmpDir(dir: string): void {
  try { rmSync(dir, { recursive: true, force: true }) } catch {}
}

function slugFor(dir: string, worktree?: string): string {
  const raw = basename(worktree || dir || "default")
  return raw.replace(/[^a-z0-9_-]/gi, "-").toLowerCase()
}

function lockPath(dir: string, slug: string): string {
  return join(dir, `.ai/telamon/memory/thinking/.capture-lock-${slug}`)
}

function writeLock(dir: string, slug: string, startedIso: string): void {
  const lockDir = join(dir, ".ai/telamon/memory/thinking")
  mkdirSync(lockDir, { recursive: true })
  writeFileSync(lockPath(dir, slug), JSON.stringify({ started: startedIso }), "utf8")
}

function makeIdleEvent(sessionId = "test-session-123") {
  return { type: "session.idle", properties: { info: { id: sessionId } } }
}

type Message = { info: { role: "user" | "assistant" }; parts: { type: string; text: string }[] }

function makeClient(opts: {
  messages?: Message[]
  onPrompt?: () => Promise<void>
} = {}) {
  let called = false
  let promptBody: any = undefined
  const client = {
    session: {
      messages: async (_args: any) => ({ data: opts.messages ?? [] }),
      prompt: async (_args: any) => {
        called = true
        promptBody = _args?.body
        if (opts.onPrompt) await opts.onPrompt()
      },
    },
    wasCalled: () => called,
    getPromptBody: () => promptBody,
  }
  return client
}

describe("RememberSessionPlugin", () => {

  describe("event type guard", () => {
    test("ignores non-session.idle events", async () => {
      const dir = makeTmpDir()
      try {
        const client = makeClient()
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: { type: "session.start", properties: { info: { id: "s1" } } } })
        expect(client.wasCalled()).toBe(false)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("ignores events without sessionId", async () => {
      const dir = makeTmpDir()
      try {
        const client = makeClient()
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: { type: "session.idle", properties: {} } })
        expect(client.wasCalled()).toBe(false)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("lock file guard", () => {
    test("no lock + no matching last message → fires prompt", async () => {
      const dir = makeTmpDir()
      try {
        const client = makeClient({ messages: [] })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: makeIdleEvent() })
        expect(client.wasCalled()).toBe(true)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("fresh lock (< 10 min old) → skips prompt", async () => {
      const dir = makeTmpDir()
      try {
        const slug = slugFor(dir)
        const freshTs = new Date(Date.now() - 2 * 60 * 1000).toISOString() // 2 min ago
        writeLock(dir, slug, freshTs)
        const client = makeClient({ messages: [] })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: makeIdleEvent() })
        expect(client.wasCalled()).toBe(false)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("stale lock (> 10 min old) → fires prompt", async () => {
      const dir = makeTmpDir()
      try {
        const slug = slugFor(dir)
        const staleTs = new Date(Date.now() - 15 * 60 * 1000).toISOString() // 15 min ago
        writeLock(dir, slug, staleTs)
        const client = makeClient({ messages: [] })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: makeIdleEvent() })
        expect(client.wasCalled()).toBe(true)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("last-message check", () => {
    test("last user message contains [Telamon] → skips (capture just finished)", async () => {
      const dir = makeTmpDir()
      try {
        const messages: Message[] = [
          { info: { role: "user" }, parts: [{ type: "text", text: "[Telamon] Please load the `telamon.remember_session` skill and run it now." }] },
          { info: { role: "assistant" }, parts: [{ type: "text", text: "Done." }] },
        ]
        const client = makeClient({ messages })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: makeIdleEvent() })
        expect(client.wasCalled()).toBe(false)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("last user message is normal text → fires prompt", async () => {
      const dir = makeTmpDir()
      try {
        const messages: Message[] = [
          { info: { role: "user" }, parts: [{ type: "text", text: "Can you help me with something?" }] },
          { info: { role: "assistant" }, parts: [{ type: "text", text: "Sure." }] },
        ]
        const client = makeClient({ messages })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: makeIdleEvent() })
        expect(client.wasCalled()).toBe(true)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("lock file lifecycle", () => {
    test("lock file acquired before prompt fires", async () => {
      const dir = makeTmpDir()
      try {
        const slug = slugFor(dir)
        const lPath = lockPath(dir, slug)
        let lockExistedDuringPrompt = false
        const client = makeClient({
          messages: [],
          onPrompt: async () => {
            lockExistedDuringPrompt = existsSync(lPath)
          },
        })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: makeIdleEvent() })
        expect(lockExistedDuringPrompt).toBe(true)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("lock file released after successful prompt", async () => {
      const dir = makeTmpDir()
      try {
        const slug = slugFor(dir)
        const lPath = lockPath(dir, slug)
        const client = makeClient({ messages: [] })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: makeIdleEvent() })
        expect(existsSync(lPath)).toBe(false)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("lock file released after failed prompt (prompt throws)", async () => {
      const dir = makeTmpDir()
      try {
        const slug = slugFor(dir)
        const lPath = lockPath(dir, slug)
        const client = makeClient({
          messages: [],
          onPrompt: async () => { throw new Error("network error") },
        })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        // Should not throw
        await expect(hooks["event"]!({ event: makeIdleEvent() })).resolves.toBeUndefined()
        expect(existsSync(lPath)).toBe(false)
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("prefill error is suppressed silently (upstream opencode #13768)", async () => {
      const dir = makeTmpDir()
      try {
        const slug = slugFor(dir)
        const lPath = lockPath(dir, slug)
        const origError = console.error
        const errorCalls: string[] = []
        console.error = (...args: any[]) => { errorCalls.push(args.join(" ")) }
        try {
          const client = makeClient({
            messages: [],
            onPrompt: async () => {
              throw new Error("This model does not support assistant message prefill. The conversation must end with a user message.")
            },
          })
          const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
          await hooks["event"]!({ event: makeIdleEvent() })
          // Lock should be released
          expect(existsSync(lPath)).toBe(false)
          // console.error should NOT have been called with this error
          expect(errorCalls.some(c => c.includes("prefill"))).toBe(false)
        } finally {
          console.error = origError
        }
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("non-prefill errors are still logged via console.error", async () => {
      const dir = makeTmpDir()
      try {
        const origError = console.error
        const errorCalls: string[] = []
        console.error = (...args: any[]) => { errorCalls.push(args.join(" ")) }
        try {
          const client = makeClient({
            messages: [],
            onPrompt: async () => { throw new Error("some other API error") },
          })
          const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
          await hooks["event"]!({ event: makeIdleEvent() })
          // console.error SHOULD have been called
          expect(errorCalls.some(c => c.includes("some other API error"))).toBe(true)
        } finally {
          console.error = origError
        }
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("worktree slug", () => {
    test("uses worktree basename when provided", async () => {
      const dir = makeTmpDir()
      try {
        const worktree = "/some/path/My Worktree 123"
        const expectedSlug = "my-worktree-123"
        const lPath = lockPath(dir, expectedSlug)
        let lockUsedCorrectSlug = false
        const client = makeClient({
          messages: [],
          onPrompt: async () => {
            lockUsedCorrectSlug = existsSync(lPath)
          },
        })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree, client })
        await hooks["event"]!({ event: makeIdleEvent() })
        expect(lockUsedCorrectSlug).toBe(true)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("prompt content", () => {
    test("prompt includes synthetic flag and metadata", async () => {
      const dir = makeTmpDir()
      try {
        const client = makeClient({ messages: [] })
        const hooks = await RememberSessionPlugin({ directory: dir, worktree: undefined, client })
        await hooks["event"]!({ event: makeIdleEvent() })
        const body = client.getPromptBody()
        expect(body).toBeDefined()
        const part = body.parts[0]
        expect(part.synthetic).toBe(true)
        expect(part.metadata?.hidden).toBe(true)
        expect(part.metadata?.source).toBe("remember-session-plugin")
        expect(part.text).toContain("[Telamon]")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })
})

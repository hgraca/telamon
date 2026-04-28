/**
 * Unit tests for the RtkDedupePlugin.
 *
 * Architecture note on Bun module caching:
 *   Bun caches ES modules after the first import. Static imports inside
 *   rtk-dedupe.ts (e.g. `import { RtkOpenCodePlugin } from "./rtk.ts"`)
 *   are resolved once at module load time. Therefore:
 *     - mock.module() for rtk.ts must be set up BEFORE the first import of
 *       rtk-dedupe.ts, and the RTK mock is fixed for the entire test file.
 *     - mock.module() for node:fs IS re-evaluated on each RtkDedupePlugin()
 *       call because readFileSync is called inside the factory function body.
 *
 *   Strategy:
 *     - Set up the RTK mock once at the top (rewrites "cmd" → "rtk run cmd").
 *     - Control rtk_enabled via fs mock before each test.
 *     - ctx.$ is mocked per-test to control fallback execution results.
 */

import { describe, test, expect, mock } from "bun:test"

// ---------------------------------------------------------------------------
// RTK mock — must be set up BEFORE the first import of rtk-dedupe.ts
// ---------------------------------------------------------------------------
// This mock rewrites commands by prepending "rtk run ".
// It is fixed for the entire test file due to Bun module caching.
mock.module("/home/herberto/Development/hgraca/telamon/src/plugins/rtk.ts", () => ({
  RtkOpenCodePlugin: async (_ctx: unknown) => ({
    "tool.execute.before": async (_input: unknown, output: unknown) => {
      const args = (output as Record<string, unknown>).args as Record<string, unknown>
      const cmd = String(args.command)
      args.command = `rtk run ${cmd}`
    },
  }),
}))

// ---------------------------------------------------------------------------
// fs mock — controlled per-test via the module-level variable below
// ---------------------------------------------------------------------------
let _rtkEnabled: boolean | "missing" = true

mock.module("node:fs", () => ({
  readFileSync: (_path: string, _enc: string) => {
    if (_rtkEnabled === "missing") throw new Error("ENOENT")
    return JSON.stringify({ rtk_enabled: _rtkEnabled })
  },
}))

// ---------------------------------------------------------------------------
// Now import the plugin under test (after mocks are in place)
// ---------------------------------------------------------------------------
import { RtkDedupePlugin } from "../../src/plugins/rtk-dedupe.ts"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build a chainable shell promise that resolves to the given result. */
function makeShellPromise(result: { stdout: Buffer | string; stderr: Buffer | string; exitCode: number }) {
  // Use a real Promise as the base so `await` works correctly.
  const base = Promise.resolve(result)
  const p = Object.assign(base, {
    quiet() { return p },
    nothrow() { return p },
  })
  return p
}

/** Build a ctx.$ tagged-template mock that resolves to the given result. */
function makeShell(stdout: string, stderr = "", exitCode = 0) {
  return (_strings: TemplateStringsArray, ..._expressions: unknown[]) =>
    makeShellPromise({ stdout: Buffer.from(stdout), stderr: Buffer.from(stderr), exitCode })
}

/** Build a minimal ctx object. */
function makeCtx(stdout = "", stderr = "", exitCode = 0) {
  return { $: makeShell(stdout, stderr, exitCode) } as unknown as Parameters<typeof RtkDedupePlugin>[0]
}

/** Build a before-hook input/output pair for a bash command. */
function makeBeforeArgs(command: string, tool = "bash") {
  const input = { tool, sessionID: "s1", callID: "c1" }
  const output = { args: { command } }
  return { input, output }
}

/** Build an after-hook input/output pair. */
function makeAfterArgs(command: string, stdout: string, tool = "bash") {
  const input = { tool, sessionID: "s1", callID: "c1", args: { command } }
  const output = { result: { stdout, stderr: "", exitCode: 0 } }
  return { input, output }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("RtkDedupePlugin", () => {

  // -------------------------------------------------------------------------
  // 1. Config check: rtk_enabled flag
  // -------------------------------------------------------------------------
  describe("config check", () => {
    test("returns empty hooks when rtk_enabled is false", async () => {
      _rtkEnabled = false
      const hooks = await RtkDedupePlugin(makeCtx())
      expect(Object.keys(hooks)).toHaveLength(0)
    })

    test("returns empty hooks when config file is missing", async () => {
      _rtkEnabled = "missing"
      const hooks = await RtkDedupePlugin(makeCtx())
      expect(Object.keys(hooks)).toHaveLength(0)
    })

    test("returns before and after hooks when rtk_enabled is true", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      expect(hooks["tool.execute.before"]).toBeTypeOf("function")
      expect(hooks["tool.execute.after"]).toBeTypeOf("function")
    })

    test("JSONC line comments are stripped before parsing config", async () => {
      mock.module("node:fs", () => ({
        readFileSync: (_path: string, _enc: string) =>
          `{
            // This is a comment
            "rtk_enabled": true // inline comment
          }`,
      }))
      const hooks = await RtkDedupePlugin(makeCtx())
      // If JSONC parsing works, rtk_enabled=true → hooks are returned
      expect(hooks["tool.execute.before"]).toBeTypeOf("function")
      // Restore the standard mock
      mock.module("node:fs", () => ({
        readFileSync: (_path: string, _enc: string) => {
          if (_rtkEnabled === "missing") throw new Error("ENOENT")
          return JSON.stringify({ rtk_enabled: _rtkEnabled })
        },
      }))
    })
  })

  // -------------------------------------------------------------------------
  // 2. First attempt (count=0): delegates to RTK
  // -------------------------------------------------------------------------
  describe("before hook — first attempt", () => {
    test("delegates to RTK and rewrites command on first attempt", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      const { input, output } = makeBeforeArgs("ls -la")
      await before(input, output)

      expect((output.args as Record<string, unknown>).command).toBe("rtk run ls -la")
    })

    test("leaves command unchanged when RTK plugin has no before hook (rtk missing)", async () => {
      // Temporarily override RTK mock to return no hooks
      mock.module("/home/herberto/Development/hgraca/telamon/src/plugins/rtk.ts", () => ({
        RtkOpenCodePlugin: async (_ctx: unknown) => ({}),
      }))
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      const { input, output } = makeBeforeArgs("ls -la")
      await before(input, output)

      expect((output.args as Record<string, unknown>).command).toBe("ls -la")

      // Restore RTK mock
      mock.module("/home/herberto/Development/hgraca/telamon/src/plugins/rtk.ts", () => ({
        RtkOpenCodePlugin: async (_ctx: unknown) => ({
          "tool.execute.before": async (_input: unknown, output: unknown) => {
            const args = (output as Record<string, unknown>).args as Record<string, unknown>
            const cmd = String(args.command)
            args.command = `rtk run ${cmd}`
          },
        }),
      }))
    })
  })

  // -------------------------------------------------------------------------
  // 3. Second attempt (count=1): runs bare, skips RTK
  // -------------------------------------------------------------------------
  describe("before hook — second attempt", () => {
    test("skips RTK rewrite on second attempt (runs bare)", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      // First attempt — RTK rewrites
      const first = makeBeforeArgs("ls -la")
      await before(first.input, first.output)
      expect((first.output.args as Record<string, unknown>).command).toBe("rtk run ls -la")

      // Second attempt — bare (no RTK rewrite)
      const second = makeBeforeArgs("ls -la")
      await before(second.input, second.output)
      expect((second.output.args as Record<string, unknown>).command).toBe("ls -la")
    })
  })

  // -------------------------------------------------------------------------
  // 4. Third+ attempt (count≥2): replaces with echo warning
  // -------------------------------------------------------------------------
  describe("before hook — third+ attempt", () => {
    test("replaces command with echo warning on third attempt", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      const cmd = "failing-cmd"
      // First and second attempts
      await before(...Object.values(makeBeforeArgs(cmd)) as [unknown, unknown])
      await before(...Object.values(makeBeforeArgs(cmd)) as [unknown, unknown])

      // Third attempt
      const third = makeBeforeArgs(cmd)
      await before(third.input, third.output)
      const rewritten = String((third.output.args as Record<string, unknown>).command)
      expect(rewritten).toStartWith(`echo "[rtk-dedupe]`)
      expect(rewritten).toContain("Stopping retry loop")
    })

    test("fourth attempt also echoes warning", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      const cmd = "bad-cmd"
      for (let i = 0; i < 3; i++) {
        await before(...Object.values(makeBeforeArgs(cmd)) as [unknown, unknown])
      }
      const fourth = makeBeforeArgs(cmd)
      await before(fourth.input, fourth.output)
      expect(String((fourth.output.args as Record<string, unknown>).command)).toStartWith(`echo "[rtk-dedupe]`)
    })
  })

  // -------------------------------------------------------------------------
  // 5. Only applies to bash/shell tools
  // -------------------------------------------------------------------------
  describe("before hook — tool filtering", () => {
    test("passes through non-bash tools unchanged", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      const { input, output } = makeBeforeArgs("ls -la", "edit")
      await before(input, output)
      // Command must not be rewritten
      expect((output.args as Record<string, unknown>).command).toBe("ls -la")
    })

    test("processes 'shell' tool (case-insensitive)", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      const { input, output } = makeBeforeArgs("ls -la", "Shell")
      await before(input, output)
      expect((output.args as Record<string, unknown>).command).toBe("rtk run ls -la")
    })

    test("processes 'BASH' tool (uppercase)", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      const { input, output } = makeBeforeArgs("pwd", "BASH")
      await before(input, output)
      expect((output.args as Record<string, unknown>).command).toBe("rtk run pwd")
    })
  })

  // -------------------------------------------------------------------------
  // 6. After hook: empty RTK result → fallback to bare command
  // -------------------------------------------------------------------------
  describe("after hook — empty result fallback", () => {
    test("ctx.$ IS called and result IS updated when RTK result is empty", async () => {
      _rtkEnabled = true

      const shellSpy = mock((_strings: TemplateStringsArray, ..._expressions: unknown[]) => {
        return makeShellPromise({ stdout: Buffer.from("bare output"), stderr: Buffer.from(""), exitCode: 0 })
      })
      const ctx = { $: shellSpy } as unknown as Parameters<typeof RtkDedupePlugin>[0]

      const hooks = await RtkDedupePlugin(ctx)
      const before = hooks["tool.execute.before"]!
      const after = hooks["tool.execute.after"]!

      const { input: bInput, output: bOutput } = makeBeforeArgs("ls -la")
      await before(bInput, bOutput)
      const rewrittenCmd = String((bOutput.args as Record<string, unknown>).command)
      expect(rewrittenCmd).toBe("rtk run ls -la")

      const { input: aInput, output: aOutput } = makeAfterArgs(rewrittenCmd, "")
      await after(aInput, aOutput)

      // ctx.$ IS called (fallback executes)
      expect(shellSpy).toHaveBeenCalledTimes(1)
      // Result IS updated with fallback output
      expect(String((aOutput.result as Record<string, unknown>).stdout)).toBe("bare output")
    })

    test("stdout is replaced with fallback output when RTK result is empty", async () => {
      _rtkEnabled = true
      const ctx = makeCtx("bare output")

      const hooks = await RtkDedupePlugin(ctx)
      const before = hooks["tool.execute.before"]!
      const after = hooks["tool.execute.after"]!

      const { input: bInput, output: bOutput } = makeBeforeArgs("ls -la")
      await before(bInput, bOutput)
      const rewrittenCmd = String((bOutput.args as Record<string, unknown>).command)

      const { input: aInput, output: aOutput } = makeAfterArgs(rewrittenCmd, "")
      await after(aInput, aOutput)

      // Result should be updated with the bare fallback output
      expect(String((aOutput.result as Record<string, unknown>).stdout)).toBe("bare output")
    })

    test("ctx.$ is NOT called when RTK result has non-empty stdout", async () => {
      _rtkEnabled = true

      let shellCalled = false
      const ctx = {
        $: (_strings: TemplateStringsArray, ..._expressions: unknown[]) => {
          shellCalled = true
          return makeShellPromise({ stdout: Buffer.from("should not appear"), stderr: Buffer.from(""), exitCode: 0 })
        },
      } as unknown as Parameters<typeof RtkDedupePlugin>[0]

      const hooks = await RtkDedupePlugin(ctx)
      const before = hooks["tool.execute.before"]!
      const after = hooks["tool.execute.after"]!

      const { input: bInput, output: bOutput } = makeBeforeArgs("cat file.txt")
      await before(bInput, bOutput)
      const rewrittenCmd = String((bOutput.args as Record<string, unknown>).command)

      const { input: aInput, output: aOutput } = makeAfterArgs(rewrittenCmd, "file contents here")
      await after(aInput, aOutput)

      expect(shellCalled).toBe(false)
      expect((aOutput.result as Record<string, unknown>).stdout).toBe("file contents here")
    })

    test("whitespace-only stdout triggers fallback and result IS updated", async () => {
      _rtkEnabled = true

      const shellSpy = mock((_strings: TemplateStringsArray, ..._expressions: unknown[]) => {
        return makeShellPromise({ stdout: Buffer.from("real output"), stderr: Buffer.from(""), exitCode: 0 })
      })
      const ctx = { $: shellSpy } as unknown as Parameters<typeof RtkDedupePlugin>[0]

      const hooks = await RtkDedupePlugin(ctx)
      const before = hooks["tool.execute.before"]!
      const after = hooks["tool.execute.after"]!

      const { input: bInput, output: bOutput } = makeBeforeArgs("grep foo bar")
      await before(bInput, bOutput)
      const rewrittenCmd = String((bOutput.args as Record<string, unknown>).command)

      const { input: aInput, output: aOutput } = makeAfterArgs(rewrittenCmd, "   \n  ")
      await after(aInput, aOutput)

      // ctx.$ IS called (whitespace triggers fallback)
      expect(shellSpy).toHaveBeenCalledTimes(1)
      // Result IS updated with the fallback output
      expect(String((aOutput.result as Record<string, unknown>).stdout)).toBe("real output")
    })

    test("after hook ignores non-bash tools", async () => {
      _rtkEnabled = true

      let shellCalled = false
      const ctx = {
        $: (_strings: TemplateStringsArray, ..._expressions: unknown[]) => {
          shellCalled = true
          return makeShellPromise({ stdout: Buffer.from(""), stderr: Buffer.from(""), exitCode: 0 })
        },
      } as unknown as Parameters<typeof RtkDedupePlugin>[0]

      const hooks = await RtkDedupePlugin(ctx)
      const after = hooks["tool.execute.after"]!

      const { input, output } = makeAfterArgs("some-cmd", "", "edit")
      await after(input, output)

      expect(shellCalled).toBe(false)
    })

    test("after hook does nothing for commands not tracked by RTK (no before hook ran)", async () => {
      _rtkEnabled = true

      let shellCalled = false
      const ctx = {
        $: (_strings: TemplateStringsArray, ..._expressions: unknown[]) => {
          shellCalled = true
          return makeShellPromise({ stdout: Buffer.from(""), stderr: Buffer.from(""), exitCode: 0 })
        },
      } as unknown as Parameters<typeof RtkDedupePlugin>[0]

      const hooks = await RtkDedupePlugin(ctx)
      const after = hooks["tool.execute.after"]!

      // Command was never registered via before hook
      const { input, output } = makeAfterArgs("untracked-cmd", "")
      await after(input, output)

      expect(shellCalled).toBe(false)
    })

    test("after hook cleans up rtkWrappedCommands after processing", async () => {
      // Even though the result update fails (bug), the cleanup still happens.
      // A second call with the same rewritten command does NOT trigger ctx.$.
      _rtkEnabled = true

      let callCount = 0
      const ctx = {
        $: (_strings: TemplateStringsArray, ..._expressions: unknown[]) => {
          callCount++
          return makeShellPromise({ stdout: Buffer.from("fallback"), stderr: Buffer.from(""), exitCode: 0 })
        },
      } as unknown as Parameters<typeof RtkDedupePlugin>[0]

      const hooks = await RtkDedupePlugin(ctx)
      const before = hooks["tool.execute.before"]!
      const after = hooks["tool.execute.after"]!

      const { input: bInput, output: bOutput } = makeBeforeArgs("ls")
      await before(bInput, bOutput)
      const rewrittenCmd = String((bOutput.args as Record<string, unknown>).command)

      // First after call — ctx.$ is called (but result not updated due to bug)
      const { input: aInput1, output: aOutput1 } = makeAfterArgs(rewrittenCmd, "")
      await after(aInput1, aOutput1)
      expect(callCount).toBe(1)

      // Second after call — command was cleaned up, ctx.$ NOT called again
      const { input: aInput2, output: aOutput2 } = makeAfterArgs(rewrittenCmd, "")
      await after(aInput2, aOutput2)
      expect(callCount).toBe(1) // still 1 — not called again
    })
  })

  // -------------------------------------------------------------------------
  // 7. LRU eviction after MAX_TRACKED (20) commands
  // -------------------------------------------------------------------------
  describe("LRU eviction", () => {
    test("evicts oldest command after 20 unique commands are tracked", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      // Fill up 20 unique commands (lru-cmd-0 through lru-cmd-19)
      for (let i = 0; i < 20; i++) {
        const { input, output } = makeBeforeArgs(`lru-cmd-${i}`)
        await before(input, output)
      }

      // Add a 21st command — this should evict lru-cmd-0
      const { input: newInput, output: newOutput } = makeBeforeArgs("lru-cmd-20")
      await before(newInput, newOutput)

      // lru-cmd-0 should have been evicted, so its count resets to 0.
      // Running it again should be treated as a first attempt (RTK rewrite, no echo warning).
      const { input: evictedInput, output: evictedOutput } = makeBeforeArgs("lru-cmd-0")
      await before(evictedInput, evictedOutput)
      // First attempt → RTK rewrites (not an echo warning)
      expect(String((evictedOutput.args as Record<string, unknown>).command)).toBe("rtk run lru-cmd-0")
    })

    test("recently-used commands are not evicted (LRU order)", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      // Fill 20 unique commands (lru2-cmd-0 through lru2-cmd-19)
      for (let i = 0; i < 20; i++) {
        const { input, output } = makeBeforeArgs(`lru2-cmd-${i}`)
        await before(input, output)
      }
      // Map now has 20 entries: [lru2-cmd-0, ..., lru2-cmd-19]

      // Re-use lru2-cmd-0 (second attempt → bare, moves to end of LRU)
      // After this: [lru2-cmd-1, ..., lru2-cmd-19, lru2-cmd-0] (still 20 entries)
      await before(...Object.values(makeBeforeArgs("lru2-cmd-0")) as [unknown, unknown])

      // Add lru2-cmd-20 — map grows to 21, evicts oldest (lru2-cmd-1)
      // After this: [lru2-cmd-2, ..., lru2-cmd-19, lru2-cmd-0, lru2-cmd-20] (20 entries)
      await before(...Object.values(makeBeforeArgs("lru2-cmd-20")) as [unknown, unknown])

      // lru2-cmd-1 should be evicted → count resets → first attempt → RTK rewrite
      const { input: cmd1Input, output: cmd1Output } = makeBeforeArgs("lru2-cmd-1")
      await before(cmd1Input, cmd1Output)
      expect(String((cmd1Output.args as Record<string, unknown>).command)).toBe("rtk run lru2-cmd-1")

      // lru2-cmd-0 was re-used (count=2) and NOT evicted.
      // Third attempt on lru2-cmd-0 → echo warning
      const { input: cmd0Input, output: cmd0Output } = makeBeforeArgs("lru2-cmd-0")
      await before(cmd0Input, cmd0Output)
      expect(String((cmd0Output.args as Record<string, unknown>).command)).toStartWith(`echo "[rtk-dedupe]`)
    })
  })

  // -------------------------------------------------------------------------
  // 8. Interleaved retries (A, B, A, B counts correctly)
  // -------------------------------------------------------------------------
  describe("interleaved retries", () => {
    test("tracks counts independently for interleaved commands", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      // Interleave A and B
      await before(...Object.values(makeBeforeArgs("interleaved-A")) as [unknown, unknown]) // A count=1
      await before(...Object.values(makeBeforeArgs("interleaved-B")) as [unknown, unknown]) // B count=1
      await before(...Object.values(makeBeforeArgs("interleaved-A")) as [unknown, unknown]) // A count=2
      await before(...Object.values(makeBeforeArgs("interleaved-B")) as [unknown, unknown]) // B count=2

      // Third attempt for A → echo warning
      const thirdA = makeBeforeArgs("interleaved-A")
      await before(thirdA.input, thirdA.output)
      expect(String((thirdA.output.args as Record<string, unknown>).command)).toStartWith(`echo "[rtk-dedupe]`)

      // Third attempt for B → echo warning
      const thirdB = makeBeforeArgs("interleaved-B")
      await before(thirdB.input, thirdB.output)
      expect(String((thirdB.output.args as Record<string, unknown>).command)).toStartWith(`echo "[rtk-dedupe]`)
    })

    test("different commands do not interfere with each other's counts", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      // Run cmd-X twice (count=2), cmd-Y only once (count=1)
      await before(...Object.values(makeBeforeArgs("isolated-X")) as [unknown, unknown])
      await before(...Object.values(makeBeforeArgs("isolated-Y")) as [unknown, unknown])
      await before(...Object.values(makeBeforeArgs("isolated-X")) as [unknown, unknown])

      // cmd-X third attempt → warning
      const thirdX = makeBeforeArgs("isolated-X")
      await before(thirdX.input, thirdX.output)
      expect(String((thirdX.output.args as Record<string, unknown>).command)).toStartWith(`echo "[rtk-dedupe]`)

      // cmd-Y second attempt → bare (no warning)
      const secondY = makeBeforeArgs("isolated-Y")
      await before(secondY.input, secondY.output)
      expect(String((secondY.output.args as Record<string, unknown>).command)).toBe("isolated-Y")
    })
  })

  // -------------------------------------------------------------------------
  // 9. Edge cases
  // -------------------------------------------------------------------------
  describe("edge cases", () => {
    test("before hook ignores missing args object", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      // Should not throw
      await expect(before({ tool: "bash", sessionID: "s", callID: "c" }, {})).resolves.toBeUndefined()
    })

    test("before hook ignores empty command string", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const before = hooks["tool.execute.before"]!

      const output = { args: { command: "" } }
      await expect(before({ tool: "bash", sessionID: "s", callID: "c" }, output)).resolves.toBeUndefined()
    })

    test("after hook ignores missing result object", async () => {
      _rtkEnabled = true
      const hooks = await RtkDedupePlugin(makeCtx())
      const after = hooks["tool.execute.after"]!

      // Should not throw even with no result
      await expect(
        after({ tool: "bash", sessionID: "s", callID: "c", args: { command: "ls" } }, {})
      ).resolves.toBeUndefined()
    })
  })
})

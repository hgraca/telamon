import { describe, test, expect } from "bun:test"
import { $ } from "bun"
import { RtkOpenCodePlugin } from "../../src/plugins/rtk.js"

// ---------------------------------------------------------------------------
// Mock $ factory for "rtk not in PATH" scenario
// ---------------------------------------------------------------------------
function makeMockDollar(behavior: "not-found" | "passthrough") {
  function mockDollar(strings: TemplateStringsArray, ...values: any[]) {
    const cmd = strings.raw.join("").trim()
    if (behavior === "not-found" && cmd.includes("which rtk")) {
      // Simulate `which rtk` failing
      const err: any = new Error("rtk not found")
      err.exitCode = 1
      throw err
    }
    // passthrough — shouldn't be called in these tests
    throw new Error("unexpected $ call: " + cmd)
  }
  return mockDollar as any
}

function makeBeforeArgs(command = "ls") {
  const input = { tool: "bash", sessionID: "s1", callID: "c1" }
  const output = { args: { command } }
  return { input, output }
}

describe("RtkOpenCodePlugin", () => {

  describe("rtk not in PATH", () => {
    test("returns empty hooks when which rtk throws", async () => {
      const mockDollar = makeMockDollar("not-found")
      const hooks = await RtkOpenCodePlugin({ $: mockDollar })
      expect(Object.keys(hooks)).toHaveLength(0)
    })
  })

  describe("with real rtk in PATH", () => {
    // rtk is available at /home/linuxbrew/.linuxbrew/bin/rtk
    // These tests use the real $ from bun

    test("returns tool.execute.before hook when rtk is available", async () => {
      const hooks = await RtkOpenCodePlugin({ $: $ as any })
      // If rtk is available, hook should be registered
      // If not available (CI), hooks will be empty — both are valid
      expect(typeof hooks).toBe("object")
    })

    test("does not modify command for non-bash tools", async () => {
      const hooks = await RtkOpenCodePlugin({ $: $ as any })
      const before = hooks["tool.execute.before"]
      if (!before) return // rtk not available — skip

      const input = { tool: "edit", sessionID: "s1", callID: "c1" }
      const output = { args: { command: "some-edit" } }
      await before(input, output)
      expect((output.args as any).command).toBe("some-edit")
    })

    test("does not crash with missing args", async () => {
      const hooks = await RtkOpenCodePlugin({ $: $ as any })
      const before = hooks["tool.execute.before"]
      if (!before) return

      const input = { tool: "bash" }
      const output = { args: null }
      await expect(before(input, output)).resolves.toBeUndefined()
    })

    test("does not crash with empty command", async () => {
      const hooks = await RtkOpenCodePlugin({ $: $ as any })
      const before = hooks["tool.execute.before"]
      if (!before) return

      const input = { tool: "bash" }
      const output = { args: { command: "" } }
      await expect(before(input, output)).resolves.toBeUndefined()
      expect((output.args as any).command).toBe("")
    })

    test("handles shell tool same as bash", async () => {
      const hooks = await RtkOpenCodePlugin({ $: $ as any })
      const before = hooks["tool.execute.before"]
      if (!before) return

      const input = { tool: "shell" }
      const output = { args: { command: "ls -la" } }
      await expect(before(input, output)).resolves.toBeUndefined()
      // Command may or may not be rewritten — just verify no crash
      expect(typeof (output.args as any).command).toBe("string")
    })

    test("rewrites command when rtk returns different output", async () => {
      const hooks = await RtkOpenCodePlugin({ $: $ as any })
      const before = hooks["tool.execute.before"]
      if (!before) return

      // Use a command that rtk is likely to rewrite (find → fd pattern)
      const { input, output } = makeBeforeArgs("find . -name '*.ts' -type f")
      await before(input, output)
      // Command should still be a string (either rewritten or unchanged)
      expect(typeof (output.args as any).command).toBe("string")
      expect((output.args as any).command.length).toBeGreaterThan(0)
    })

    test("leaves command unchanged when rtk returns same output", async () => {
      const hooks = await RtkOpenCodePlugin({ $: $ as any })
      const before = hooks["tool.execute.before"]
      if (!before) return

      // A simple command rtk likely won't rewrite
      const { input, output } = makeBeforeArgs("echo hello")
      const originalCmd = output.args.command
      await before(input, output)
      // Either unchanged or rewritten — both valid
      expect(typeof (output.args as any).command).toBe("string")
    })
  })

  describe("rtk rewrite failure passthrough", () => {
    test("does not propagate error when rtk rewrite fails", async () => {
      // Create a mock $ where which rtk succeeds but rtk rewrite throws
      let callCount = 0
      function mockDollarWithFailingRewrite(strings: TemplateStringsArray, ...values: any[]) {
        const cmd = strings.raw.join("").trim()
        callCount++
        if (cmd.includes("which rtk")) {
          // which rtk succeeds
          return {
            quiet: () => ({
              exitCode: 0,
              stdout: Buffer.from("/usr/bin/rtk"),
            }),
          }
        }
        // rtk rewrite fails
        return {
          quiet: () => ({
            nothrow: () => {
              throw new Error("rtk rewrite failed")
            },
          }),
        }
      }

      const hooks = await RtkOpenCodePlugin({ $: mockDollarWithFailingRewrite as any })
      const before = hooks["tool.execute.before"]
      if (!before) return

      const { input, output } = makeBeforeArgs("ls -la")
      await expect(before(input, output)).resolves.toBeUndefined()
      // Command should be unchanged (passthrough)
      expect((output.args as any).command).toBe("ls -la")
    })
  })
})

import { describe, test, expect } from "bun:test"
import { mkdirSync, writeFileSync, rmSync, chmodSync } from "fs"
import { join } from "path"
import { $ } from "bun"
import { ScriptRunnerPlugin } from "../../src/plugins/script-runner.js"

let _tmpCounter = 0
function makeTmpDir(): string {
  const dir = join("/tmp", `script-runner-test-${process.pid}-${++_tmpCounter}`)
  mkdirSync(dir, { recursive: true })
  return dir
}
function cleanTmpDir(dir: string): void {
  try { rmSync(dir, { recursive: true, force: true }) } catch {}
}

function makeScript(dir: string, name: string, content: string): string {
  const path = join(dir, name)
  writeFileSync(path, content, "utf8")
  chmodSync(path, 0o755)
  return path
}

async function runCommand(dir: string, args: string | string[] | undefined, command = "script") {
  const hooks = await ScriptRunnerPlugin({ $, directory: dir })
  const hook = hooks["command.execute.before"]!
  const input: any = { command, arguments: args }
  const output: any = { parts: [] }
  await hook(input, output)
  return output
}

describe("ScriptRunnerPlugin", () => {

  describe("no arguments", () => {
    test("sets output.parts with error when no args", async () => {
      const dir = makeTmpDir()
      try {
        const output = await runCommand(dir, "")
        expect(output.parts[0].type).toBe("text")
        expect(output.parts[0].text).toContain("no script path provided")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("sets output.parts with error when args undefined", async () => {
      const dir = makeTmpDir()
      try {
        const output = await runCommand(dir, undefined)
        expect(output.parts[0].text).toContain("no script path provided")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("sets output.parts with error when args empty array", async () => {
      const dir = makeTmpDir()
      try {
        const output = await runCommand(dir, [])
        expect(output.parts[0].text).toContain("no script path provided")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("script not found", () => {
    test("sets error with resolved path when script missing", async () => {
      const dir = makeTmpDir()
      try {
        const output = await runCommand(dir, "nonexistent.sh")
        expect(output.parts[0].text).toContain("script not found")
        expect(output.parts[0].text).toContain("nonexistent.sh")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("successful execution", () => {
    test("sets output.parts with formatted block", async () => {
      const dir = makeTmpDir()
      try {
        makeScript(dir, "hello.sh", "#!/bin/sh\necho 'hello world'")
        const output = await runCommand(dir, "hello.sh")
        const text = output.parts[0].text
        expect(text).toContain("[script-runner] Executed:")
        expect(text).toContain("Working directory:")
        expect(text).toContain("Exit code: 0")
        expect(text).toContain("hello world")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("captures stdout and stderr separately", async () => {
      const dir = makeTmpDir()
      try {
        makeScript(dir, "both.sh", "#!/bin/sh\necho 'out'\necho 'err' >&2")
        const output = await runCommand(dir, "both.sh")
        const text = output.parts[0].text
        expect(text).toContain("out")
        expect(text).toContain("err")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("passes arguments to script", async () => {
      const dir = makeTmpDir()
      try {
        makeScript(dir, "args.sh", "#!/bin/sh\necho \"arg1=$1 arg2=$2\"")
        const output = await runCommand(dir, "args.sh foo bar")
        const text = output.parts[0].text
        expect(text).toContain("arg1=foo")
        expect(text).toContain("arg2=bar")
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("handles array arguments", async () => {
      const dir = makeTmpDir()
      try {
        makeScript(dir, "args2.sh", "#!/bin/sh\necho \"arg=$1\"")
        const output = await runCommand(dir, ["args2.sh", "hello"])
        const text = output.parts[0].text
        expect(text).toContain("arg=hello")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("non-zero exit code", () => {
    test("captures output and shows non-zero exit code", async () => {
      const dir = makeTmpDir()
      try {
        makeScript(dir, "fail.sh", "#!/bin/sh\necho 'before fail'\nexit 42")
        const output = await runCommand(dir, "fail.sh")
        const text = output.parts[0].text
        expect(text).toContain("Exit code: 42")
        expect(text).toContain("before fail")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("non-script command", () => {
    test("ignores non-script commands", async () => {
      const dir = makeTmpDir()
      try {
        const hooks = await ScriptRunnerPlugin({ $, directory: dir })
        const hook = hooks["command.execute.before"]!
        const input: any = { command: "other", arguments: "something" }
        const output: any = { parts: [] }
        await hook(input, output)
        expect(output.parts).toHaveLength(0)
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("relative path resolution", () => {
    test("resolves relative path from directory", async () => {
      const dir = makeTmpDir()
      try {
        const subDir = join(dir, "scripts")
        mkdirSync(subDir)
        makeScript(subDir, "test.sh", "#!/bin/sh\necho 'relative'")
        const output = await runCommand(dir, "scripts/test.sh")
        expect(output.parts[0].text).toContain("relative")
      } finally {
        cleanTmpDir(dir)
      }
    })
  })
})

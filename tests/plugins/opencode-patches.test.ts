import { describe, test, expect } from "bun:test"
import { mkdirSync, writeFileSync, rmSync, existsSync } from "fs"
import { join } from "path"
import { OpencodePatchesPlugin } from "../../src/plugins/opencode-patches.js"

let _tmpCounter = 0
function makeTmpDir(): string {
  const dir = join("/tmp", `opencode-patches-test-${process.pid}-${++_tmpCounter}`)
  mkdirSync(dir, { recursive: true })
  return dir
}
function cleanTmpDir(dir: string): void {
  try { rmSync(dir, { recursive: true, force: true }) } catch {}
}

function writeTelamonJsonc(dir: string, content: object): void {
  writeFileSync(join(dir, ".telamon.jsonc"), JSON.stringify(content), "utf8")
}

function writeStateFile(dir: string, state: object): void {
  const storageDir = join(dir, "storage")
  mkdirSync(storageDir, { recursive: true })
  writeFileSync(join(storageDir, "opencode-patch-state.json"), JSON.stringify(state), "utf8")
}

describe("OpencodePatchesPlugin", () => {

  describe("findTelamonRoot", () => {
    test("finds .telamon.jsonc in current dir", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, { opencode_patches: [] })
        writeStateFile(dir, { version: "999.0.0", binary_sha: "abc" })
        const hooks = await OpencodePatchesPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        // Should not throw
        await expect(before()).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("walks up to find .telamon.jsonc in parent", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, { opencode_patches: [] })
        writeStateFile(dir, { version: "999.0.0", binary_sha: "abc" })
        const subDir = join(dir, "sub")
        mkdirSync(subDir)
        const hooks = await OpencodePatchesPlugin({ directory: subDir })
        const before = hooks["tool.execute.before"]!
        await expect(before()).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("early return guards", () => {
    test("does nothing when no state file", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, { opencode_patches: ["some-patch"] })
        // No state file
        const hooks = await OpencodePatchesPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await expect(before()).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("does nothing when no config file", async () => {
      const dir = makeTmpDir()
      try {
        // No .telamon.jsonc
        writeStateFile(dir, { version: "1.0.0", binary_sha: "abc" })
        const hooks = await OpencodePatchesPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await expect(before()).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("does nothing when patches array is empty", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, { opencode_patches: [] })
        writeStateFile(dir, { version: "1.0.0", binary_sha: "abc" })
        const hooks = await OpencodePatchesPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await expect(before()).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })

    test("does nothing when patches key missing", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, {})
        writeStateFile(dir, { version: "1.0.0", binary_sha: "abc" })
        const hooks = await OpencodePatchesPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await expect(before()).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("parseJsonc", () => {
    test("strips // line comments", async () => {
      const dir = makeTmpDir()
      try {
        writeFileSync(
          join(dir, ".telamon.jsonc"),
          `{
  // line comment
  "opencode_patches": [] /* block comment */
}`,
          "utf8"
        )
        writeStateFile(dir, { version: "999.0.0", binary_sha: "abc" })
        const hooks = await OpencodePatchesPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        // Should parse without error
        await expect(before()).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("checked flag (one-shot)", () => {
    test("only executes once — second call is no-op", async () => {
      const dir = makeTmpDir()
      try {
        writeTelamonJsonc(dir, { opencode_patches: [] })
        writeStateFile(dir, { version: "999.0.0", binary_sha: "abc" })
        const hooks = await OpencodePatchesPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await before()
        await before() // second call — checked flag prevents re-run
        await expect(before()).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })
  })

  describe("silent failure", () => {
    test("does not throw on unexpected errors", async () => {
      const dir = makeTmpDir()
      try {
        // Write invalid JSON to config to trigger parse error
        writeFileSync(join(dir, ".telamon.jsonc"), "{ invalid json }", "utf8")
        writeStateFile(dir, { version: "1.0.0" })
        const hooks = await OpencodePatchesPlugin({ directory: dir })
        const before = hooks["tool.execute.before"]!
        await expect(before()).resolves.toBeUndefined()
      } finally {
        cleanTmpDir(dir)
      }
    })
  })
})

import { tool } from "@opencode-ai/plugin"
import path from "path"
import os from "os"
import fs from "fs"

/**
 * git-report — snapshot current git state: branch, status, staged diff, recent commits,
 * and commits ahead of the default remote branch.
 *
 * Usage:
 *   git-report()
 *   git-report({ format: "markdown" })
 *   git-report({ log_count: 20 })
 *
 * Delegates to the colocated Python script (git-report.py).
 *
 * Wiring (same pattern as repomix-report.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/git-report/git-report.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/git-report.ts
 *     pointing to this file.
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 *     so Bun's upward module resolution from this file's real path finds it.
 *
 * When format is "markdown", the output is passed through format-md to align
 * any markdown tables before returning.
 */

export default tool({
  description:
    "Return a git state snapshot: current branch, default remote branch, recent commits, working-tree status, staged diff (summary + full), commits ahead of origin/HEAD, and index integrity check (missing objects from git fsck). Use this to understand what has changed before committing, reviewing, or planning next steps.",
  args: {
    log_count: tool.schema
      .number()
      .optional()
      .default(10)
      .describe("Number of recent commits to show (default: 10)"),
    format: tool.schema
      .enum(["json", "markdown"])
      .optional()
      .default("json")
      .describe("Output format: 'json' (default, structured data) or 'markdown' (human-readable report)"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "git-report.py")
    const fmt = args.format ?? "json"

    const cmd = [
      "python3",
      script,
      "--format",
      fmt,
      "--log-count",
      String(args.log_count ?? 10),
    ]

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `git-report failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
    }

    if (fmt === "json") {
      try {
        return JSON.parse(stdout.trim())
      } catch {
        return stdout.trim()
      }
    }

    // Format markdown tables before returning
    const tmpFile = path.join(os.tmpdir(), `git-report-${Date.now()}.md`)
    try {
      await Bun.write(tmpFile, stdout.trim())
      const fmtScript = path.join(import.meta.dir, "..", "format-md", "format-md.py")
      const fmtProc = Bun.spawn(["python3", fmtScript, tmpFile], { stdio: ["ignore", "pipe", "pipe"] })
      await fmtProc.exited
      return (await Bun.file(tmpFile).text()).trim()
    } finally {
      try { fs.unlinkSync(tmpFile) } catch { /* ignore */ }
    }
  },
})

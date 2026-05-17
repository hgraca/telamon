import { tool } from "@opencode-ai/plugin"
import path from "path"
import os from "os"
import fs from "fs"

/**
 * git-report — snapshot current git state.
 *
 * Args (no Zod schema — args:{} to avoid cross-instance crash, see opencode gotcha):
 *   log_count  number  optional  Number of recent commits (default: 10)
 *   format     string  optional  "json" (default) or "markdown"
 */

export default tool({
  description:
    "Return a git state snapshot: current branch, default remote branch, recent commits, working-tree status, staged diff (summary + full), commits ahead of origin/HEAD, and index integrity check (missing objects from git fsck). Use this to understand what has changed before committing, reviewing, or planning next steps.\n\nParameters:\n- log_count (number, optional): Number of recent commits to show (default: 10)\n- format (string, optional): 'json' (default) or 'markdown'",
  args: {},
  async execute(rawArgs) {
    const args = rawArgs as any
    const script = path.join(import.meta.dir, "git-report.py")
    const fmt = (args.format as string | undefined) ?? "json"

    const cmd = [
      "python3",
      script,
      "--format",
      fmt,
      "--log-count",
      String((args.log_count as number | undefined) ?? 10),
    ]

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `git-report failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
    }

    if (fmt === "json") {
      return stdout.trim()
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

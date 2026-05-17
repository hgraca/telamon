import { tool } from "@opencode-ai/plugin"
import path from "path"
import os from "os"
import fs from "fs"

/**
 * tree — run `tree` on one or more directories and output markdown to stdout.
 *
 * Args (passed as raw object — no Zod schema to avoid cross-instance crash, opencode issue #21155):
 *   paths   string  required  Path or JSON array string e.g. '["src","lib"]' or 'src'
 *   format  string  optional  "json" (default) or "markdown"
 */

export default tool({
  description:
    "Run `tree` on one or more directories and return markdown output showing the full directory tree with all subfolders and files. Use this to explore directory structure.\n\nParameters:\n- paths (string, required): directory path or multiple paths. Accepts: single path 'src', JSON array '[\"src\",\"lib\"]', comma-separated 'src,lib', or space-separated 'src lib'\n- format (string, optional): 'json' (default) or 'markdown'",
  args: {},
  async execute(rawArgs) {
    const args = rawArgs as any
    const script = path.join(import.meta.dir, "tree.sh")
    const fmt = (args.format as string | undefined) ?? "json"

    // coerce string (plain, JSON array, comma-separated, or space-separated) to string[]
    const paths: string[] = (() => {
      const raw = (args.paths as string | undefined) ?? ""
      if (!raw) return []
      // Try JSON array first
      try {
        const parsed = JSON.parse(raw)
        if (Array.isArray(parsed)) return parsed.map(String).filter(Boolean)
      } catch { /* not JSON */ }
      // Try comma-separated
      if (raw.includes(",")) return raw.split(",").map(s => s.trim()).filter(Boolean)
      // Try space-separated (multiple tokens that look like paths)
      const parts = raw.split(/\s+/).filter(Boolean)
      if (parts.length > 1) return parts
      // Single plain path
      return [raw]
    })()
    if (paths.length === 0) {
      return "tree: 'paths' argument is required"
    }

    const cmd = ["bash", script, "--format", fmt, ...paths]

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `tree failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
    }

    if (fmt === "json") {
      return stdout.trim()
    }

    // Format markdown tables before returning
    const tmpFile = path.join(os.tmpdir(), `tree-${Date.now()}.md`)
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

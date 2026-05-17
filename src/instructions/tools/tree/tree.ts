import { tool } from "@opencode-ai/plugin"
import path from "path"
import os from "os"
import fs from "fs"

/**
 * tree — run `tree` on one or more directories and output markdown to stdout.
 *
 * Usage:
 *   tree({ paths: ["src/components"] })
 *   tree({ paths: ["src/components", "src/utils"] })
 *
 * Always outputs markdown to stdout (no file written).
 * Delegates to the colocated bash script (tree.sh).
 *
 * Wiring (same pattern as format-md.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/tree/tree.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/tree.ts
 *     pointing to this file.
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 *     so Bun's upward module resolution from this file's real path finds it.
 */

export default tool({
  description:
    "Run `tree` on one or more directories and return markdown output showing the full directory tree with all subfolders and files. Use this to explore directory structure.",
  args: {
    paths: tool.schema
      .array(tool.schema.string())
      .describe(
        "One or more directory paths to inspect. Each is resolved relative to the project root if relative, or used as-is if absolute. E.g. ['src/components'] or ['src/components', 'src/utils'].",
      ),
    format: tool.schema
      .enum(["json", "markdown"])
      .optional()
      .default("json")
      .describe("Output format: 'json' (default, structured data) or 'markdown' (human-readable tree output)"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "tree.sh")
    const fmt = args.format ?? "json"

    // Normalise paths: guard against undefined or a JSON-encoded string arriving
    // instead of a parsed array (opencode schema coercion edge case).
    let paths: string[]
    if (!args.paths) {
      return "tree: 'paths' argument is required"
    } else if (Array.isArray(args.paths)) {
      paths = args.paths
    } else {
      // Received a raw string — try JSON-parse first, then treat as single path
      try {
        const parsed = JSON.parse(args.paths as unknown as string)
        paths = Array.isArray(parsed) ? parsed : [String(parsed)]
      } catch {
        paths = [String(args.paths)]
      }
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
      try {
        return JSON.parse(stdout.trim())
      } catch {
        return stdout.trim()
      }
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

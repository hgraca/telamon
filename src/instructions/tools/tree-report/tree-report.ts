import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * tree-report — run `tree` on one or more directories and output markdown to stdout.
 *
 * Usage:
 *   tree-report({ paths: ["src/components"] })
 *   tree-report({ paths: ["src/components", "src/utils"] })
 *
 * Always outputs markdown to stdout (no file written).
 * Delegates to the colocated bash script (tree-report.sh).
 *
 * Wiring (same pattern as repomix-report.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/tree-report/tree-report.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/tree-report.ts
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
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "tree-report.sh")

    const cmd = ["bash", script, ...args.paths]

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `tree-report failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
    }

    return stdout.trim()
  },
})

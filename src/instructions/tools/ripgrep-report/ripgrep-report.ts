import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * ripgrep-report — search the codebase for keywords and return the top N most
 * relevant folders ranked by match density.
 *
 * Usage:
 *   ripgrep_report({ keywords: ["authentication", "JWT"] })
 *   ripgrep_report({ keywords: ["payment", "stripe"], top: 5, format: "markdown" })
 *   ripgrep_report({ keywords: ["cache"], root: "src/", format: "json" })
 *
 * Delegates to the colocated bash script (ripgrep-report.sh) which uses
 * ripgrep (rg) under the hood. Folders are scored by total match count across
 * all keywords; ties broken alphabetically.
 *
 * Wiring (same pattern as tree-report.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/ripgrep-report/ripgrep-report.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/ripgrep-report.ts
 *     pointing to this file.
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 *     so Bun's upward module resolution from this file's real path finds it.
 *
 * Dependencies:
 *   rg (ripgrep) — must be installed on the host
 *   python3      — used for scoring and JSON assembly inside the bash script
 */

export default tool({
  description:
    "Search the codebase for one or more keywords or phrases using ripgrep and return the top 10 most relevant folders ranked by match density. Use this to quickly locate which parts of the codebase are most related to a concept, feature, or domain term.",
  args: {
    keywords: tool.schema
      .array(tool.schema.string())
      .describe(
        "One or more words or phrases to search for. Each is searched independently; folders are ranked by combined match count. E.g. ['authentication', 'JWT token'] or ['payment', 'stripe', 'invoice'].",
      ),
    format: tool.schema
      .enum(["json", "markdown"])
      .optional()
      .default("json")
      .describe("Output format: 'json' (default, structured data) or 'markdown' (human-readable table)."),
    root: tool.schema
      .string()
      .optional()
      .describe(
        "Root directory to search. Defaults to the project root (git worktree). Use a subdirectory to narrow the search scope, e.g. 'src/' or 'tests/'.",
      ),
    top: tool.schema
      .number()
      .optional()
      .default(10)
      .describe("Number of top folders to return. Defaults to 10."),
  },
  async execute(args, context) {
    const script = path.join(import.meta.dir, "ripgrep-report.sh")
    const fmt = args.format ?? "json"
    const top = String(args.top ?? 10)
    const root = args.root ?? context.worktree

    const cmd = [
      "bash",
      script,
      "--format", fmt,
      "--root", root,
      "--top", top,
      ...args.keywords,
    ]

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `ripgrep-report failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
    }

    if (fmt === "json") {
      try {
        return JSON.parse(stdout.trim())
      } catch {
        return stdout.trim()
      }
    }

    return stdout.trim()
  },
})

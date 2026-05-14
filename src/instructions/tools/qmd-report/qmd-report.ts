import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * qmd-report — search the project memory vault via QMD and return full file contents as Markdown.
 *
 * Usage:
 *   qmd_report({ query: "planning workflow" })
 *   qmd_report({ query: ["planning", "workflow"] })
 *   qmd_report({ query: "planning workflow", collection: "telamon", max_results: 5 })
 *
 * Delegates to the colocated Python script (qmd-report.py).
 * The script holds the pure analysis logic and is independently testable from the CLI.
 *
 * Wiring (same pattern as format-md.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/qmd-report/qmd-report.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/qmd-report.ts
 *     pointing to this file.
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 *     so Bun's upward module resolution from this file's real path finds it.
 */

export default tool({
  description:
    "Search the project memory vault using QMD (semantic + keyword search) and return full file contents as Markdown. Use this to find relevant documentation, memories, patterns, decisions, and work archives in the project's .ai/telamon/memory vault.",
  args: {
    query: tool.schema
      .array(tool.schema.string())
      .describe(
        "One or more search queries. Each query is run independently and results are merged. Use multiple queries for different aspects of what you're looking for. E.g. ['planning workflow'] or ['planning', 'workflow'].",
      ),
    collection: tool.schema
      .string()
      .optional()
      .default("telamon")
      .describe("QMD collection to search (default: telamon — the project memory vault)"),
    max_results: tool.schema
      .number()
      .optional()
      .default(5)
      .describe("Maximum number of matching files to return (default: 5)"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "qmd-report.py")

    const cmd = [
      "python3",
      script,
      "--format",
      "markdown",
      "--collection",
      args.collection ?? "telamon",
      "--max-results",
      String(args.max_results ?? 5),
    ]

    // Add each query as a separate --query argument
    const queries = Array.isArray(args.query) ? args.query : [args.query]
    for (const q of queries) {
      cmd.push("--query", q)
    }

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `qmd-report failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
    }

    return stdout.trim()
  },
})
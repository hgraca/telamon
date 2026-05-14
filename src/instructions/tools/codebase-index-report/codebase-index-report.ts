import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * codebase-index-report — search the codebase by meaning using the codebase-index MCP.
 *
 * Usage:
 *   codebase-index-report({ query: "rate limiter" })
 *   codebase-index-report({ query: ["payment handler", "auth middleware"] })
 *   codebase-index-report({ query: "rate limiter", max_results: 10, file_type: "ts" })
 *
 * Delegates to the colocated Python script (codebase-index-report.py).
 * The script holds the pure search logic and is independently testable from the CLI.
 *
 * Wiring (same pattern as format-md.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/codebase-index-report/codebase-index-report.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/codebase-index-report.ts
 *     pointing to this file.
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 *     so Bun's upward module resolution from this file's real path finds it.
 */

export default tool({
  description:
    "Search the codebase by meaning using the codebase-index MCP and return full code contents as Markdown. Use this to find relevant code, understand architecture, locate definitions, or explore the codebase by semantic meaning rather than keywords.",
  args: {
    query: tool.schema
      .array(tool.schema.string())
      .describe(
        "One or more search queries describing what code you're looking for. Each query is run independently and results are merged. Use natural language descriptions of behavior, not keywords. E.g. ['rate limiter implementation'] or ['payment handler', 'auth middleware'].",
      ),
    max_results: tool.schema
      .number()
      .optional()
      .default(5)
      .describe("Maximum number of matching files to return (default: 5)"),
    file_type: tool.schema
      .string()
      .optional()
      .describe("Filter by file extension (e.g. 'ts', 'py', 'php', 'rs')"),
    directory: tool.schema
      .string()
      .optional()
      .describe("Filter by directory path (e.g. 'src/utils', 'lib')"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "codebase-index-report.py")

    const cmd = [
      "python3",
      script,
      "--format",
      "markdown",
      "--max-results",
      String(args.max_results ?? 5),
    ]

    if (args.file_type) {
      cmd.push("--file-type", args.file_type)
    }
    if (args.directory) {
      cmd.push("--directory", args.directory)
    }

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
      return `codebase-index-report failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
    }

    return stdout.trim()
  },
})
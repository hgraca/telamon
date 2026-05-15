import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"

/**
 * qmd-report — search the project memory vault via QMD and return full file contents as Markdown.
 *
 * Usage:
 *   qmd-report({ query: "planning workflow" })
 *   qmd-report({ query: ["planning", "workflow"] })
 *   qmd-report({ query: "planning workflow", collection: "my-project", max_results: 5 })
 *
 * The collection defaults to the project name from .ai/telamon/telamon.jsonc.
 * Delegates to the colocated Python script (qmd-report.py).
 *
 * Wiring (same pattern as format-md.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/qmd-report/qmd-report.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/qmd-report.ts
 *     pointing to this file.
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 *     so Bun's upward module resolution from this file's real path finds it.
 */

function resolveProjectCollection(): string {
  // Try reading project name from .ai/telamon/telamon.jsonc relative to CWD
  const configPath = path.join(process.cwd(), ".ai", "telamon", "telamon.jsonc")
  try {
    const raw = fs.readFileSync(configPath, "utf8")
    const config = JSON.parse(raw)
    if (config.project_name) return config.project_name
  } catch {
    // Fall through to default
  }
  return "telamon"
}

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
      .describe("QMD collection to search (default: auto-detected from .ai/telamon/telamon.jsonc project_name)"),
    max_results: tool.schema
      .number()
      .optional()
      .default(5)
      .describe("Maximum number of matching files to return (default: 5)"),
    format: tool.schema
      .enum(["json", "markdown"])
      .optional()
      .default("json")
      .describe("Output format: 'json' (default, structured data) or 'markdown' (human-readable report)"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "qmd-report.py")
    const collection = args.collection ?? resolveProjectCollection()
    const fmt = args.format ?? "json"

    const cmd = [
      "python3",
      script,
      "--format",
      fmt,
      "--collection",
      collection,
      "--max-results",
      String(args.max_results ?? 5),
    ]

    // Add each query as a separate --query argument
    const queries = Array.isArray(args.query) ? args.query : [args.query]
    for (const q of queries) {
      cmd.push("--query", q)
    }

    // Pass TELAMON_ROOT so the Python script can find the qmd cache path
    const env = { ...process.env }
    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"], env })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `qmd-report failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
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

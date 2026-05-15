import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"

/**
 * gather-context — gather memory + codebase context for a set of keywords.
 *
 * Orchestrates three tools in sequence:
 *   1. qmd-report   — search memory vault for relevant notes/decisions
 *   2. graphify-report — find most-connected nodes matching keywords, extract folders
 *   3. tree-report  — show directory trees for the relevant folders
 *
 * Usage:
 *   gather-context({ keywords: ["planning", "workflow"] })
 *   gather-context({ keywords: ["memory"], format: "markdown" })
 *
 * Always returns JSON by default (markdown via format: "markdown").
 * Delegates to the colocated Python script (gather-context.py).
 *
 * Wiring (same pattern as tree-report.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/gather-context/gather-context.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/gather-context.ts
 *     pointing to this file.
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 *     so Bun's upward module resolution from this file's real path finds it.
 */

function resolveProjectCollection(): string {
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
    "Gather memory vault notes and codebase graph context for a set of keywords, then show directory trees for the most relevant folders. Use this at the start of any non-trivial session to prime context about a topic. Orchestrates qmd-report (memory), graphify-report (architecture), and tree-report (directory structure).",
  args: {
    keywords: tool.schema
      .array(tool.schema.string())
      .describe(
        "One or more keywords describing the topic or feature area. E.g. ['planning', 'workflow'] or ['memory', 'skill']. Each keyword is searched independently across memory vault and codebase graph.",
      ),
    format: tool.schema
      .enum(["json", "markdown"])
      .optional()
      .default("json")
      .describe("Output format: 'json' (default, structured data) or 'markdown' (human-readable report)"),
    top_n: tool.schema
      .number()
      .optional()
      .default(10)
      .describe("Number of top god nodes to include from graphify (default: 10)"),
    max_results: tool.schema
      .number()
      .optional()
      .default(5)
      .describe("Maximum number of memory vault results from qmd-report (default: 5)"),
    graph_path: tool.schema
      .string()
      .optional()
      .default("graphify-out/graph.json")
      .describe("Path to graph.json relative to project root (default: graphify-out/graph.json)"),
    collection: tool.schema
      .string()
      .optional()
      .describe("QMD collection name (default: auto-detected from .ai/telamon/telamon.jsonc project_name)"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "gather-context.py")
    const fmt = args.format ?? "json"
    const collection = args.collection ?? resolveProjectCollection()

    const cmd = [
      "python3",
      script,
      "--format",
      fmt,
      "--collection",
      collection,
      "--top-n",
      String(args.top_n ?? 10),
      "--max-results",
      String(args.max_results ?? 5),
      "--graph-path",
      args.graph_path ?? "graphify-out/graph.json",
      ...args.keywords,
    ]

    const env = {
      ...process.env,
      XDG_CACHE_HOME: path.join(import.meta.dir, "../../../../storage"),
      QMD_LLAMA_GPU: "true",
    }

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"], env })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `gather-context failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
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

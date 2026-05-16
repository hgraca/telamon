import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * gather-context-from-code — gather code context for a list of words or sentences.
 *
 * Orchestrates graphify-report to find the most relevant file and folder nodes,
 * deduplicates overlapping folders (keeping the coarsest paths), then runs
 * `tree` on each folder to produce a structural overview.
 *
 * Output includes:
 *   - Top 10 most relevant file paths (from graphify top_file_nodes)
 *   - Top 10 most relevant folder paths (deduplicated to coarsest)
 *   - Directory tree for each deduplicated folder
 *
 * Wiring (same pattern as graphify-report.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/gather-context-from-code/gather-context-from-code.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/gather-context-from-code.ts
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 */

export default tool({
  description:
    "Gather code context for a list of words or sentences. Uses the knowledge graph to find the 10 most relevant file nodes and 10 most relevant folder nodes, deduplicates overlapping folders (keeping coarsest paths), and runs tree on each folder. Returns file paths, folder paths, and directory trees. Use this to quickly orient around code relevant to a topic.",
  args: {
    words: tool.schema
      .array(tool.schema.string())
      .describe(
        "One or more words or sentences describing the topic. E.g. ['planning', 'workflow'] or ['memory skill']. Each entry is treated as a search term.",
      ),
    graph_path: tool.schema
      .string()
      .optional()
      .default("graphify-out/graph.json")
      .describe("Path to graph.json relative to project root (default: graphify-out/graph.json)"),
    top_n: tool.schema
      .number()
      .optional()
      .default(10)
      .describe("Number of top file/folder nodes to retrieve (default: 10)"),
    format: tool.schema
      .enum(["json", "markdown"])
      .optional()
      .default("json")
      .describe("Output format: 'json' (default, structured data) or 'markdown' (human-readable)"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "gather-context-from-code.py")
    const fmt = args.format ?? "json"

    const cmd = [
      "python3",
      script,
      "--graph-path", args.graph_path ?? "graphify-out/graph.json",
      "--top-n", String(args.top_n ?? 10),
      "--format", fmt,
      ...args.words,
    ]

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `gather-context-from-code failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
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

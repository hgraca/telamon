import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * graphify-report — read graph.json and produce Markdown summary + word deep-dive.
 *
 * Two modes:
 *   1. Summary only: graphify_report()
 *   2. Word deep-dive: graphify_report({ words: "planning,workflow" })
 *
 * Delegates to the colocated Python script (graphify-report.py).
 * The script holds the pure analysis logic and is independently testable from the CLI.
 *
 * Wiring (same pattern as format-md.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/graphify-report/graphify-report.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/graphify-report.ts
 *     pointing to this file.
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 *     so Bun's upward module resolution from this file's real path finds it.
 */

export default tool({
  description:
    "Read graphify-out/graph.json and produce a Markdown report (stats, god nodes, communities) and optionally dive deep into nodes matching specific words. Use this to understand codebase architecture, find most connected components, and explore relationships around specific concepts.",
  args: {
    words: tool.schema
      .string()
      .optional()
      .describe(
        "Comma-separated words to filter and dive deep into matching nodes. E.g. 'planning,workflow' or 'memory,skill'. When omitted, returns only summary stats and god nodes.",
      ),
    top_n: tool.schema
      .number()
      .optional()
      .default(10)
      .describe("Number of top god nodes to show (default: 10)"),
    graph_path: tool.schema
      .string()
      .optional()
      .default("graphify-out/graph.json")
      .describe("Path to graph.json relative to project root (default: graphify-out/graph.json)"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "graphify-report.py")

    const cmd = [
      "python3",
      script,
      "--graph-path",
      args.graph_path ?? "graphify-out/graph.json",
      "--top-n",
      String(args.top_n ?? 10),
      "--format",
      "markdown",
    ]

    if (args.words) {
      cmd.push("--words", args.words)
    }

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `graphify-report failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
    }

    return stdout.trim()
  },
})
import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"

/**
 * gather-context — orchestrate context-gathering tools for a set of keywords.
 *
 * Currently orchestrates:
 *   1. gather-context-from-memory — search memory vault, return full file bodies
 *
 * More tools will be added over time.
 *
 * Usage:
 *   gather-context({ keywords: ["planning", "workflow"] })
 *   gather-context({ keywords: ["memory"], format: "markdown" })
 *
 * Delegates to the colocated Python script (gather-context.py).
 *
 * Wiring:
 *   - This file lives at <telamon-root>/src/instructions/tools/gather-context/gather-context.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/gather-context.ts
 *   - `@opencode-ai/plugin` is at src/instructions/tools/node_modules/
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
    "Gather context for a set of keywords by orchestrating multiple context sources. Currently searches the memory vault (notes, decisions, patterns). More sources will be added over time. Use at the start of any non-trivial session to prime context about a topic.",
  args: {
    keywords: tool.schema
      .array(tool.schema.string())
      .describe(
        "One or more keywords or phrases describing the topic. E.g. ['planning', 'workflow'] or ['memory', 'skill'].",
      ),
    format: tool.schema
      .enum(["json", "markdown"])
      .optional()
      .default("json")
      .describe("Output format: 'json' (default) or 'markdown' (human-readable)"),
    max_results: tool.schema
      .number()
      .optional()
      .default(5)
      .describe("Maximum number of memory vault results (default: 5)"),
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
      "--format", fmt,
      "--collection", collection,
      "--max-results", String(args.max_results ?? 5),
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

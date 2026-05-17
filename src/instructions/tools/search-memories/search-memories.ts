import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"

/**
 * search-memories — search the project memory vault and return full file bodies.
 *
 * Searches the QMD memory vault for files matching the given queries, then
 * fetches each matched file's full content (frontmatter stripped) and assembles
 * all bodies into a single output.
 *
 * Usage:
 *   search-memories({ query: ["planning", "workflow"] })
 *   search-memories({ query: ["billing"], format: "markdown" })
 *   search-memories({ query: ["auth"], max_results: 10 })
 *
 * Always returns JSON by default (markdown via format: "markdown").
 * Delegates to the colocated Python script (search-memories.py).
 *
 * Wiring (same pattern as format-md.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/search-memories/search-memories.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/search-memories.ts
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
    "Search the project memory vault using QMD (semantic + keyword search) and return full file contents as Markdown. Use this to find relevant documentation, memories, patterns, decisions, and work archives in the project's .ai/telamon/memory vault.",
  args: {
    query: tool.schema
      .union([tool.schema.string(), tool.schema.array(tool.schema.string())])
      .describe(
        "One or more search queries (words or sentences). Pass a single string or an array of strings. Each is searched independently and results are merged. E.g. 'planning workflow' or ['planning', 'workflow'].",
      ),
    collection: tool.schema
      .string()
      .optional()
      .describe(
        "Primary QMD collection to search (default: auto-detected from .ai/telamon/telamon.jsonc project_name). The 'global' collection is always included automatically.",
      ),
    max_results: tool.schema
      .number()
      .optional()
      .default(5)
      .describe("Maximum number of matched files to return (default: 5)"),
    format: tool.schema
      .enum(["json", "markdown"])
      .optional()
      .default("json")
      .describe("Output format: 'json' (default, structured data) or 'markdown' (human-readable, file bodies separated by ---)"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "search-memories.py")
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

    const queries = Array.isArray(args.query) ? args.query : [args.query]
    for (const q of queries) {
      cmd.push("--query", q)
    }

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
      return `search-memories failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
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

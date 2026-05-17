import { tool } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"

/**
 * search-memories — search the project memory vault and return full file bodies.
 *
 * Args (passed as raw object — no Zod schema to avoid cross-instance crash, opencode issue #21155):
 *   query       string  required  Search query or JSON array string e.g. '["planning","workflow"]'
 *   collection  string  optional  QMD collection name (default: auto-detected)
 *   max_results number  optional  Max files to return (default: 5)
 *   format      string  optional  "json" (default) or "markdown"
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
    "Search the project memory vault using QMD (semantic + keyword search) and return full file contents as Markdown. Use this to find relevant documentation, memories, patterns, decisions, and work archives in the project's .ai/telamon/memory vault.\n\nParameters:\n- query (string, required): search query or JSON array string e.g. '[\"planning\",\"workflow\"]' or 'billing'\n- collection (string, optional): QMD collection name (default: auto-detected from telamon.jsonc)\n- max_results (number, optional): max files to return (default: 5)\n- format (string, optional): 'json' (default) or 'markdown'",
  args: {},
  async execute(rawArgs) {
    const args = rawArgs as any
    const script = path.join(import.meta.dir, "search-memories.py")
    const collection = (args.collection as string | undefined) ?? resolveProjectCollection()
    const fmt = (args.format as string | undefined) ?? "json"

    const cmd = [
      "python3",
      script,
      "--format",
      fmt,
      "--collection",
      collection,
      "--max-results",
      String((args.max_results as number | undefined) ?? 5),
    ]

    const queries: string[] = (() => {
      const raw = (args.query as string | undefined) ?? ""
      if (!raw) return []
      try {
        const parsed = JSON.parse(raw)
        if (Array.isArray(parsed)) return parsed.map(String).filter(Boolean)
      } catch { /* not JSON — treat as plain string */ }
      return [raw]
    })()
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
      return stdout.trim()
    }

    return stdout.trim()
  },
})

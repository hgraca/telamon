import { tool } from "@opencode-ai/plugin"
import { createHash } from "crypto"
import { mkdir, readFile, writeFile, unlink } from "fs/promises"
import { existsSync, readFileSync } from "fs"
import path from "path"

// ── helpers ──────────────────────────────────────────────────────────────────

function computeHash(keywords: string[]): string {
  const key = [...keywords].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase())).join(",")
  return createHash("sha256").update(key).digest("hex")
}

function parseTtlMs(ttl: string): number {
  const match = ttl.match(/^(\d+)(d|h|m)$/)
  if (!match) return 7 * 24 * 60 * 60 * 1000 // fallback 7d
  const n = parseInt(match[1], 10)
  switch (match[2]) {
    case "d": return n * 24 * 60 * 60 * 1000
    case "h": return n * 60 * 60 * 1000
    case "m": return n * 60 * 1000
    default:  return 7 * 24 * 60 * 60 * 1000
  }
}

/**
 * Strip JSONC comments without corrupting string values.
 * Walks the source character-by-character, tracking whether we are inside
 * a double-quoted string (and handling backslash escapes), so that `//`
 * inside a URL like "https://..." is never treated as a comment delimiter.
 */
function stripJsoncComments(src: string): string {
  let out = ""
  let i = 0
  while (i < src.length) {
    // Inside a string literal
    if (src[i] === '"') {
      out += src[i++]
      while (i < src.length) {
        if (src[i] === "\\") { out += src[i] + src[i + 1]; i += 2; continue }
        if (src[i] === '"')  { out += src[i++]; break }
        out += src[i++]
      }
      continue
    }
    // Single-line comment
    if (src[i] === "/" && src[i + 1] === "/") {
      while (i < src.length && src[i] !== "\n") i++
      continue
    }
    // Block comment
    if (src[i] === "/" && src[i + 1] === "*") {
      i += 2
      while (i < src.length && !(src[i] === "*" && src[i + 1] === "/")) i++
      i += 2
      continue
    }
    out += src[i++]
  }
  return out
}

function readJsonc(filePath: string): Record<string, unknown> {
  try {
    const raw = readFileSync(filePath, "utf8")
    return JSON.parse(stripJsoncComments(raw))
  } catch {
    return {}
  }
}

function getTtlConfig(): string {
  const cwd = process.cwd()
  for (const name of [".telamon.jsonc", ".telamon.dist.jsonc"]) {
    const p = path.join(cwd, name)
    if (existsSync(p)) {
      const cfg = readJsonc(p)
      const ttl = (cfg as any)?.skill?.["gather-context"]?.["context-cache"]?.ttl
      if (typeof ttl === "string") return ttl
    }
  }
  return "7d"
}

function parseFrontmatter(content: string): { ttl_end?: string; body: string } {
  if (!content.startsWith("---\n")) return { body: content }
  const end = content.indexOf("\n---\n", 4)
  if (end === -1) return { body: content }
  const fm = content.slice(4, end)
  const body = content.slice(end + 5)
  const match = fm.match(/^ttl_end:\s*(.+)$/m)
  return { ttl_end: match?.[1]?.trim(), body }
}

function cachePath(hash: string): string {
  return path.join(process.cwd(), ".ai", "telamon", "cache", "gather-context", `${hash}.md`)
}

// ── tool ─────────────────────────────────────────────────────────────────────

export default tool({
  description:
    "Cache and retrieve gather-context reports keyed by a SHA-256 hash of sorted keywords. " +
    "subcommand 'get': returns 'Cached at <absolute-path>\\n\\n<body>' if valid cache hit, empty string on miss/expiry. " +
    "subcommand 'store': writes content to cache with TTL-derived expiry frontmatter, returns 'Cached at <absolute-path> (expires <iso>)'. Rejects empty content.\n\n" +
    "Parameters:\n" +
    "- subcommand (string, required): 'get' to retrieve cached report; 'store' to write report to cache\n" +
    "- keywords (string, required): topic keywords — JSON array string e.g. '[\"auth\",\"jwt\"]' or single keyword e.g. 'billing'\n" +
    "- content (string, optional): report content to store (required for 'store'; must be non-empty)",
  args: {},
  async execute(rawArgs) {
    const args = rawArgs as any
    const keywords: string[] = (() => {
      const raw = (args.keywords as string | undefined) ?? ""
      if (!raw) return []
      try {
        const parsed = JSON.parse(raw)
        if (Array.isArray(parsed)) return parsed.map(String).filter(Boolean)
      } catch { /* not JSON — treat as plain keyword */ }
      return [raw]
    })()
    const hash = computeHash(keywords)
    const filePath = cachePath(hash)

    if ((args.subcommand as string) === "get") {
      if (!existsSync(filePath)) return ""
      const raw = await readFile(filePath, "utf8")
      const { ttl_end, body } = parseFrontmatter(raw)
      if (!ttl_end || Date.now() >= new Date(ttl_end).getTime()) {
        await unlink(filePath).catch(() => {})
        return ""
      }
      return `Cached at ${filePath}\n\n${body}`
    }

    // store
    const content = (args.content as string | undefined) ?? ""
    if (content.trim().length === 0) {
      return "Error: content must not be empty — cache not written"
    }
    const ttlStr = getTtlConfig()
    const ttlMs = parseTtlMs(ttlStr)
    const ttl_end = new Date(Date.now() + ttlMs).toISOString()
    const fileContent = `---\nttl_end: ${ttl_end}\n---\n${content}`
    await mkdir(path.dirname(filePath), { recursive: true })
    await writeFile(filePath, fileContent, "utf8")

    // Format markdown tables in the written file (fire-and-forget).
    // writeFile bypasses opencode's file.edited event, so the format-md plugin
    // never fires — we call it explicitly here to stay deterministic.
    try {
      const script = path.join(import.meta.dir, "../format-md/format-md.py")
      const proc = Bun.spawn(["python3", script, filePath], {
        stdio: ["ignore", "ignore", "ignore"],
        detached: true,
      })
      proc.unref()
    } catch { /* graceful degradation */ }

    return `Cached at ${filePath} (expires ${ttl_end})`
  },
})

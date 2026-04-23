import { readFileSync } from "node:fs"
import { join } from "node:path"
import type { Plugin } from "@opencode-ai/plugin"
import { RtkOpenCodePlugin } from "./rtk.ts"

// Wrapper around the upstream RTK OpenCode plugin that adds duplicate
// detection. When the agent issues the same command more than twice, the
// third invocation is replaced with a warning echo — breaking retry loops
// where the agent keeps re-running a failing command.
//
// Dedup logic:
//   - recentCommands tracks the last MAX_TRACKED unique commands with their
//     attempt count, using Map insertion order for FIFO eviction.
//   - 1st attempt: delegate to RTK for rewriting.
//   - 2nd attempt (same command): run bare, bypassing RTK.
//   - 3rd+ attempt: replace with echo warning, stopping the retry loop.
//
// Unlike the previous single-lastCommand approach, this catches interleaved
// retries (A, B, C, A, B, C) — not just immediate consecutive duplicates.
//
// rtk.ts is NOT registered in opencode.jsonc — only this wrapper is.
// rtk.ts is kept in src/plugins/ as an import dependency.

export const RtkDedupePlugin: Plugin = async (ctx) => {
  // Read telamon.ini and check rtk_enabled flag.
  // Defaults to disabled if file is missing or key is absent.
  let rtkEnabled = false
  try {
    const iniPath = join(process.cwd(), ".ai/telamon/telamon.ini")
    const iniContent = readFileSync(iniPath, "utf8")
    const match = iniContent.match(/^\s*rtk_enabled\s*=\s*(\S+)/m)
    if (match && match[1].toLowerCase() === "true") {
      rtkEnabled = true
    }
  } catch {
    // File missing — default to disabled
  }

  if (!rtkEnabled) {
    return {}
  }

  // Initialise the upstream RTK plugin, forwarding the full plugin context.
  // If rtk binary is not in PATH, RtkOpenCodePlugin returns {} and rtkBefore
  // will be undefined — the wrapper then passes all commands through unchanged.
  const rtkHooks = await RtkOpenCodePlugin(ctx)
  const rtkBefore = (rtkHooks as Record<string, unknown>)?.["tool.execute.before"] as
    | ((input: unknown, output: unknown) => Promise<void>)
    | undefined

  // Track recent commands with attempt counts.
  // Uses Map insertion order for FIFO eviction.
  const recentCommands = new Map<string, number>()
  const MAX_TRACKED = 20
  const MAX_ATTEMPTS = 2

  return {
    "tool.execute.before": async (input, output) => {
      const tool = String((input as Record<string, unknown>)?.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return

      const args = (output as Record<string, unknown>)?.args
      if (!args || typeof args !== "object") return

      const command = (args as Record<string, unknown>).command
      if (typeof command !== "string" || !command) return

      const count = recentCommands.get(command) ?? 0

      if (count >= MAX_ATTEMPTS) {
        // Already tried via RTK and bare — block with warning
        recentCommands.set(command, count + 1)
        ;(args as Record<string, unknown>).command =
          `echo "[rtk-dedupe] This exact command was already attempted ${count} times. Stopping retry loop — try a different approach or tool. If this is a CLI for an authenticated service (e.g. gh, aws), verify auth is working or use the equivalent MCP tool instead."`
        return
      }

      // Track this attempt (delete + set moves entry to end of Map for LRU)
      recentCommands.delete(command)
      recentCommands.set(command, count + 1)

      // Evict oldest entries if over limit
      while (recentCommands.size > MAX_TRACKED) {
        const oldest = recentCommands.keys().next().value
        if (oldest !== undefined) recentCommands.delete(oldest)
        else break
      }

      if (count === 0) {
        // First attempt — delegate to RTK for rewriting
        if (rtkBefore) {
          await rtkBefore(input, output)
        }
      }
      // count === 1 → second attempt, run bare (skip RTK rewrite)
    },
  }
}

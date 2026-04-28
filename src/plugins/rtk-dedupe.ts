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
//   - 1st attempt: delegate to RTK for rewriting. If RTK result is empty or
//     whitespace-only, immediately fallback to bare command execution.
//   - 2nd attempt (same command): run bare, bypassing RTK.
//   - 3rd+ attempt: replace with echo warning, stopping the retry loop.
//
// Unlike the previous single-lastCommand approach, this catches interleaved
// retries (A, B, C, A, B, C) — not just immediate consecutive duplicates.
//
// rtk.ts is NOT registered in opencode.jsonc — only this wrapper is.
// rtk.ts is kept in src/plugins/ as an import dependency.

export const RtkDedupePlugin: Plugin = async (ctx) => {
  // Read telamon.jsonc and check rtk_enabled flag.
  // Defaults to disabled if file is missing or key is absent.
  let rtkEnabled = false
  try {
    const cfgPath = join(process.cwd(), ".ai/telamon/telamon.jsonc")
    const raw = readFileSync(cfgPath, "utf8")
    // Strip JSONC comments (// line comments)
    const stripped = raw.replace(/(?<![:"'])\/\/.*$/gm, "")
    const cfg = JSON.parse(stripped)
    if (cfg.rtk_enabled === true) {
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

  // Track commands that were RTK-wrapped in first attempt, storing the
  // original command for potential fallback if RTK result is empty.
  // Key: rewritten command, Value: original command
  const rtkWrappedCommands = new Map<string, string>()

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
        // First attempt — store original command, then delegate to RTK for rewriting
        const originalCommand = command
        if (rtkBefore) {
          await rtkBefore(input, output)
          // Track the rewritten command for potential fallback in after hook
          const rewrittenCommand = (args as Record<string, unknown>).command
          if (typeof rewrittenCommand === "string" && rewrittenCommand !== originalCommand) {
            rtkWrappedCommands.set(rewrittenCommand, originalCommand)
          }
        }
      }
      // count === 1 → second attempt, run bare (skip RTK rewrite)
    },

    "tool.execute.after": async (input, output) => {
      const tool = String((input as Record<string, unknown>)?.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return

      const args = (input as Record<string, unknown>)?.args
      if (!args || typeof args !== "object") return

      const command = (args as Record<string, unknown>).command
      if (typeof command !== "string" || !command) return

      // Check if this was a RTK-wrapped command
      const originalCommand = rtkWrappedCommands.get(command)
      if (!originalCommand) return

      // Check if result is empty or whitespace-only
      const result = (output as Record<string, unknown>)?.result
      const stdout = String((result as Record<string, unknown>)?.stdout ?? "")
      const isEmptyOrWhitespace = !stdout || stdout.trim() === ""

      if (isEmptyOrWhitespace) {
        // RTK result was empty — execute the original bare command as fallback
        try {
          const $ = ctx.$
          const fallbackResult = await $`${originalCommand}`.quiet().nothrow()

          // Replace the result with the fallback execution.
          // Uses Object.assign to avoid a Bun compilation bug where consecutive
          // cast-expression assignments get merged into chained calls.
          if (result && typeof result === "object") {
            Object.assign(result as Record<string, unknown>, {
              stdout: fallbackResult.stdout,
              stderr: fallbackResult.stderr,
              exitCode: fallbackResult.exitCode,
            })
          }
        } catch {
          // Fallback execution failed — keep original empty result
        }
      }

      // Clean up tracking
      rtkWrappedCommands.delete(command)
    },
  }
}

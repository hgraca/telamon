import type { Plugin } from "@opencode-ai/plugin"
import { RtkOpenCodePlugin } from "./rtk.ts"

// Wrapper around the upstream RTK OpenCode plugin that adds consecutive-duplicate
// detection. When the agent issues the exact same command twice in a row, the
// second invocation bypasses RTK and runs the command bare. This prevents the
// agent from getting stuck in a loop where RTK-rewritten commands produce the
// same failure repeatedly — giving the bare command a chance to succeed.
//
// Dedup logic:
//   - lastCommand is set to the original command before delegating to RTK.
//   - If the next command equals lastCommand, it is passed through unchanged
//     and lastCommand is reset to null.
//   - On reset, the command after the bare one will delegate to RTK again,
//     creating an alternating pattern for repeated identical commands:
//     RTK → bare → RTK → bare → …
//
// rtk.ts is NOT registered in opencode.jsonc — only this wrapper is.
// rtk.ts is kept in src/plugins/ as an import dependency.

export const RtkDedupePlugin: Plugin = async (ctx) => {
  // Initialise the upstream RTK plugin, forwarding the full plugin context.
  // If rtk binary is not in PATH, RtkOpenCodePlugin returns {} and rtkBefore
  // will be undefined — the wrapper then passes all commands through unchanged.
  const rtkHooks = await RtkOpenCodePlugin(ctx)
  const rtkBefore = (rtkHooks as Record<string, unknown>)?.["tool.execute.before"] as
    | ((input: unknown, output: unknown) => Promise<void>)
    | undefined

  let lastCommand: string | null = null

  return {
    "tool.execute.before": async (input, output) => {
      const tool = String((input as Record<string, unknown>)?.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return

      const args = (output as Record<string, unknown>)?.args
      if (!args || typeof args !== "object") return

      const command = (args as Record<string, unknown>).command
      if (typeof command !== "string" || !command) return

      if (command === lastCommand) {
        // 2nd consecutive identical command — run bare, reset state
        lastCommand = null
        return
      }

      // Record this command, then delegate to the upstream RTK plugin
      lastCommand = command
      if (rtkBefore) {
        await rtkBefore(input, output)
      }
    },
  }
}

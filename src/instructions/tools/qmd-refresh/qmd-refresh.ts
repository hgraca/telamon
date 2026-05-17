import { tool } from "@opencode-ai/plugin"

/**
 * qmd-refresh — runs `qmd update && qmd embed` in the background.
 *
 * Fires-and-forgets: the command is launched detached so it never blocks
 * the agent turn. Output is discarded (>/dev/null 2>&1 & disown).
 *
 * Usage:
 *   qmd-refresh()
 *
 * Wiring:
 *   - This file lives at <telamon-root>/src/instructions/tools/qmd-refresh/qmd-refresh.ts
 *   - opencode/init.sh creates a flat symlink at <project>/.opencode/tools/qmd-refresh.ts
 *   - @opencode-ai/plugin resolves via src/instructions/tools/node_modules/
 */

export default tool({
  description:
    "Refresh the QMD knowledge base by running `qmd update && qmd embed` in the background. " +
    "Use after editing memory files under .ai/telamon/memory/latent/ to keep the semantic index current. " +
    "The command runs detached and never blocks — returns immediately.",
  args: {},
  async execute(_args, context) {
    const worktree = context.worktree ?? process.cwd()

    // Launch detached — fire and forget, never blocks the agent turn.
    // Bun.spawn with detached:true + unref() mirrors `cmd >/dev/null 2>&1 & disown`.
    try {
      const proc = Bun.spawn(
        ["bash", "-c", "qmd update && qmd embed"],
        {
          cwd: worktree,
          stdio: ["ignore", "ignore", "ignore"],
          detached: true,
        },
      )
      proc.unref()

      return JSON.stringify({
        status: "ok",
        message: "qmd update && qmd embed launched in background",
      })
    } catch (err) {
      return JSON.stringify({
        status: "error",
        code: "QMD_REFRESH_FAILED",
        message: err instanceof Error ? err.message : String(err),
      })
    }
  },
})

import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * qmd-refresh — runs `qmd update && qmd embed` in the background.
 *
 * Fires-and-forgets: delegates to qmd-refresh.sh which launches the command
 * detached so it never blocks the agent turn.
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
  async execute(_args) {
    const script = path.join(import.meta.dir, "qmd-refresh.sh")

    try {
      const proc = Bun.spawn(["bash", script], { stdio: ["ignore", "pipe", "pipe"] })
      const stdout = await new Response(proc.stdout).text()
      const stderr = await new Response(proc.stderr).text()
      const exitCode = await proc.exited

      if (exitCode !== 0) {
        return JSON.stringify({
          status: "error",
          code: "QMD_REFRESH_FAILED",
          message: stderr.trim() || stdout.trim() || `exit ${exitCode}`,
        })
      }

      try {
        return JSON.parse(stdout.trim())
      } catch {
        return stdout.trim()
      }
    } catch (err) {
      return JSON.stringify({
        status: "error",
        code: "QMD_REFRESH_FAILED",
        message: err instanceof Error ? err.message : String(err),
      })
    }
  },
})

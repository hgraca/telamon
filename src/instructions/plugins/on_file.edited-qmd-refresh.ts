import type { Plugin } from "@opencode-ai/plugin"

// on_file.edited-qmd-refresh plugin
//
// Fires `qmd update && qmd embed` in the background whenever a .md file under
// .ai/telamon/memory/latent/ is edited. Keeps the QMD semantic index current
// without requiring manual invocation.
//
// Hook: file.edited
// Gate: file path ends with .md AND contains .ai/telamon/memory/latent/
// Action: spawns `qmd update && qmd embed` detached (fire-and-forget)

export const OnFileEditedQmdRefresh: Plugin = async ({ project }) => {
  return {
    event: async ({ event }) => {
      try {
        if (event.type !== "file.edited") return

        const file: string = (event as { type: string; properties: { file: string } }).properties?.file ?? ""

        // Gate: must be a .md file under .ai/telamon/memory/latent/
        if (!file.endsWith(".md")) return
        if (!file.includes(".ai/telamon/memory/latent")) return

        // Fire-and-forget: launch detached, never blocks the agent turn.
        // Mirrors: qmd update && qmd embed >/dev/null 2>&1 & disown
        const proc = Bun.spawn(
          ["bash", "-c", "qmd update && qmd embed >/dev/null 2>&1"],
          {
            cwd: project.worktree,
            stdio: ["ignore", "ignore", "ignore"],
            detached: true,
          },
        )
        proc.unref()
      } catch (err) {
        process.stderr.write(
          `[on_file.edited-qmd-refresh] Error: ${err instanceof Error ? err.message : String(err)}\n`,
        )
      }
    },
  }
}

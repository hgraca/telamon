import type { Plugin } from "@opencode-ai/plugin"
import path from "path"

// on_file.edited-format-md plugin
//
// Fires `format-md` in the background whenever a .md file is edited.
// Keeps markdown table columns aligned without requiring manual invocation.
//
// Hook: file.edited
// Gate: file path ends with .md
// Action: spawns `python3 format-md.py <file>` detached (fire-and-forget)

export const OnFileEditedFormatMd: Plugin = async ({ project }) => {
  return {
    event: async ({ event }) => {
      try {
        if (event.type !== "file.edited") return

        const file: string = (event as { type: string; properties: { file: string } }).properties?.file ?? ""

        // Gate: must be a .md file — exit silently for all other file types
        if (!file.endsWith(".md")) return

        // Resolve the format-md.py script relative to this plugin's real path.
        // import.meta.dir resolves through symlinks to the actual source directory.
        const script = path.join(import.meta.dir, "../tools/format-md/format-md.py")

        // Fire-and-forget: launch detached, never blocks the agent turn.
        // Mirrors: python3 format-md.py <file> >/dev/null 2>&1 & disown
        const proc = Bun.spawn(
          ["python3", script, file],
          {
            cwd: project.worktree,
            stdio: ["ignore", "ignore", "ignore"],
            detached: true,
          },
        )
        proc.unref()
      } catch {
        // Graceful degradation — never throw from hook
      }
    },
  }
}

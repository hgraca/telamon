import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * watermark-session — write the remember-session watermark file with a
 * guaranteed UTC timestamp obtained from the system clock at call time.
 *
 * Eliminates the agent timezone bug: agents must never fabricate or guess
 * the watermark timestamp. Calling this tool is the only correct way to
 * advance the watermark (see remember-session SKILL.md step 5).
 *
 * Wiring:
 *   - Lives at <telamon-root>/src/instructions/tools/watermark-session/watermark-session.ts
 *   - opencode/init.sh creates a flat symlink at <project>/.opencode/tools/watermark-session.ts
 *   - @opencode-ai/plugin resolves via src/instructions/tools/node_modules/
 */

export default tool({
  description:
    "Write the remember-session watermark file with the current UTC timestamp. " +
    "Call this as the final step of every remember-session execution (step 5). " +
    "Never fabricate or guess the timestamp — this tool is the only correct way to advance the watermark.",
  args: {
    worktree: tool.schema
      .string()
      .describe("Absolute path to the git worktree root (used to derive the watermark slug and file path)."),
  },
  async execute(args) {
    const worktree = args.worktree
    const slug = path.basename(worktree).replace(/[^a-z0-9_-]/gi, "-").toLowerCase()
    const watermarkPath = path.join(worktree, `.ai/telamon/memory/thinking/.last-capture-${slug}.json`)
    const timestamp = new Date().toISOString().replace(/\.\d{3}Z$/, "Z") // strip ms, keep Z suffix

    const payload = JSON.stringify({ timestamp, worktree }, null, 2) + "\n"

    try {
      await Bun.write(watermarkPath, payload)
      return JSON.stringify({ status: "ok", timestamp, watermark_path: watermarkPath })
    } catch (err) {
      return JSON.stringify({
        status: "error",
        code: "WATERMARK_WRITE_FAILED",
        message: err instanceof Error ? err.message : String(err),
        watermark_path: watermarkPath,
      })
    }
  },
})

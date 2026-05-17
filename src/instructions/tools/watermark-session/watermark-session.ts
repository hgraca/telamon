import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * watermark-session — write the remember-session watermark file.
 *
 * Args (no Zod schema — args:{} to avoid cross-instance crash, see opencode gotcha):
 *   worktree  string  required  Absolute path to the git worktree root
 */

export default tool({
  description:
    "Write the remember-session watermark file with the current UTC timestamp. " +
    "Call this as the final step of every remember-session execution (step 5). " +
    "Never fabricate or guess the timestamp — this tool is the only correct way to advance the watermark.\n\n" +
    "Parameters:\n- worktree (string, required): Absolute path to the git worktree root (used to derive the watermark slug and file path).",
  args: {},
  async execute(rawArgs) {
    const args = rawArgs as any
    const worktree = (args.worktree as string | undefined) ?? ""
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

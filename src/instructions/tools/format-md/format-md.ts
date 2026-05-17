import { tool } from "@opencode-ai/plugin"
import path from "path"

// format-md — align markdown table columns in a file or directory.
//
// Args (no Zod schema — args:{} to avoid cross-instance crash, see opencode gotcha):
//   path  string  required  Absolute or relative path to a .md file or directory

export default tool({
  description:
    "Align markdown table columns in a file or directory (recursive for directories). Run after writing or editing any .md file to keep tables readable.\n\nParameters:\n- path (string, required): Absolute or relative path to a markdown file or directory. Directories are walked recursively for .md files.",
  args: {},
  async execute(rawArgs) {
    const args = rawArgs as any
    const filePath = (args.path as string | undefined) ?? ""
    const script = path.join(import.meta.dir, "format-md.py")

    const result = await Bun.$`python3 ${script} ${filePath}`
      .nothrow()
      .quiet()

    const stdout = result.stdout.toString().trim()
    const stderr = result.stderr.toString().trim()

    if (result.exitCode !== 0) {
      return `format-md failed (exit ${result.exitCode})\n${stderr || stdout || "(no output)"}`
    }

    return `Formatted markdown tables in: ${filePath}${stderr ? `\n\nWarnings:\n${stderr}` : ""}`
  },
})

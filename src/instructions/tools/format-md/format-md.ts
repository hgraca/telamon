import { tool } from "@opencode-ai/plugin"
import path from "path"

// format-md — align markdown table columns in a file or directory.
//
// Delegates to the colocated Python script (format-md.py). The script holds
// the pure formatting logic and is independently testable from the CLI.
//
// Wiring (see [[gotchas]] "Opencode custom tools require flat layout AND
// co-located node_modules", 2026-05-10):
//   - This file lives at <telamon-root>/src/instructions/tools/format-md/format-md.ts
//   - init.sh creates a flat symlink at <project>/.opencode/tools/format-md.ts
//     pointing to this file. Tools nested under .opencode/tools/<dir>/ are not
//     discovered by opencode.
//   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
//     so Bun's upward module resolution from this file's real path finds it.

export default tool({
  description:
    "Align markdown table columns in a file or directory (recursive for directories). Run after writing or editing any .md file to keep tables readable.",
  args: {
    path: tool.schema
      .string()
      .describe(
        "Absolute or relative path to a markdown file or directory. Directories are walked recursively for .md files.",
      ),
  },
  async execute(args) {
    // Resolve script path relative to *this file's real path* — survives the
    // flat symlink at .opencode/tools/format-md.ts because import.meta.dir
    // reports the real directory of the source file.
    const script = path.join(import.meta.dir, "format-md.py")

    const result = await Bun.$`python3 ${script} ${args.path}`
      .nothrow()
      .quiet()

    const stdout = result.stdout.toString().trim()
    const stderr = result.stderr.toString().trim()

    if (result.exitCode !== 0) {
      return `format-md failed (exit ${result.exitCode})\n${stderr || stdout || "(no output)"}`
    }

    return `Formatted markdown tables in: ${args.path}${stderr ? `\n\nWarnings:\n${stderr}` : ""}`
  },
})

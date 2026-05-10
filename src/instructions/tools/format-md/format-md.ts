import { tool } from "@opencode-ai/plugin"
import path from "path"

// format-md — align markdown table columns in a file or directory.
//
// Delegates to the colocated Python script (format-md.py), which contains the
// pure formatting logic and is independently testable. The tool is exposed to
// the LLM as `format-md` (filename → tool name).
//
// Behaviour:
//   - If `path` is a directory, all `.md` files are formatted recursively in-place.
//   - If `path` is a file, that file is formatted in-place.
//   - Tables already aligned are left untouched (idempotent).
//
// The script writes nothing to stdout on success; on error it prints to stderr
// and exits non-zero. We surface stderr in the tool result so the LLM can react.

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
  async execute(args, context) {
    // The tool lives at <opencode-tools-root>/telamon/format-md/format-md.ts
    // (via the .opencode/tools/telamon symlink → src/instructions/tools).
    // The Python script sits next to this file.
    const script = path.join(
      context.worktree,
      ".opencode/tools/telamon/format-md/format-md.py",
    )

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

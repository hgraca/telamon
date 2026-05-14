import { tool } from "@opencode-ai/plugin"
import path from "path"

/**
 * repomix-report — package folders with --compress and output markdown to stdout.
 *
 * Usage:
 *   repomix-report({ dir: "src/components" })
 *   repomix-report({ dir: ["src/components", "src/utils"] })
 *   repomix-report({ dir: "src", no_compress: true })
 *
 * Always outputs markdown to stdout (no file written).
 * Delegates to the colocated Python script (repomix-report.py).
 *
 * Wiring (same pattern as format-md.ts):
 *   - This file lives at <telamon-root>/src/instructions/tools/repomix-report/repomix-report.ts
 *   - init.sh creates a flat symlink at <project>/.opencode/tools/repomix-report.ts
 *     pointing to this file.
 *   - `@opencode-ai/plugin` is installed at src/instructions/tools/node_modules/
 *     so Bun's upward module resolution from this file's real path finds it.
 */

export default tool({
  description:
    "Package one or more directories with repomix --compress and output markdown to stdout. Use this to pack directory contents into a single compressed context. Supports multiple directories and include/ignore patterns.",
  args: {
    dir: tool.schema
      .array(tool.schema.string())
      .describe(
        "One or more directories to pack. Each is resolved relative to the project root. E.g. ['src/components'] or ['src/components', 'src/utils'].",
      ),
    no_compress: tool.schema
      .boolean()
      .optional()
      .default(false)
      .describe("Disable Tree-sitter compression (default: false, compression enabled)"),
    include_patterns: tool.schema
      .string()
      .optional()
      .describe("Include patterns (glob, comma-separated). E.g. 'src/**/*.js,*.md'"),
    ignore_patterns: tool.schema
      .string()
      .optional()
      .describe("Ignore patterns (glob, comma-separated). E.g. '*.test.js,docs/**'"),
    top_files_length: tool.schema
      .number()
      .optional()
      .default(10)
      .describe("Number of largest files to show in metrics (default: 10)"),
  },
  async execute(args) {
    const script = path.join(import.meta.dir, "repomix-report.py")

    const cmd = [
      "python3",
      script,
      "--top-files-length",
      String(args.top_files_length ?? 10),
    ]

    if (args.no_compress) {
      cmd.push("--no-compress")
    }
    if (args.include_patterns) {
      cmd.push("--include-patterns", args.include_patterns)
    }
    if (args.ignore_patterns) {
      cmd.push("--ignore-patterns", args.ignore_patterns)
    }

    // Add each directory as a separate --dir argument
    const dirs = Array.isArray(args.dir) ? args.dir : [args.dir]
    for (const d of dirs) {
      cmd.push("--dir", d)
    }

    const proc = Bun.spawn(cmd, { stdio: ["ignore", "pipe", "pipe"] })
    const stdout = await new Response(proc.stdout).text()
    const stderr = await new Response(proc.stderr).text()
    const exitCode = await proc.exited

    if (exitCode !== 0) {
      return `repomix-report failed (exit ${exitCode})\n${stderr.trim() || stdout.trim() || "(no output)"}`
    }

    return stdout.trim()
  },
})
import { existsSync, readdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";

/**
 * Extracts the task title from a README.md with YAML frontmatter.
 * Returns the first non-empty line after the closing `---` of the frontmatter.
 */
function extractTitle(content) {
  const lines = content.split("\n");
  let inFrontmatter = false;
  let frontmatterClosed = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    if (i === 0 && line === "---") {
      inFrontmatter = true;
      continue;
    }

    if (inFrontmatter && line === "---") {
      inFrontmatter = false;
      frontmatterClosed = true;
      continue;
    }

    if (frontmatterClosed && line !== "") {
      return line.replace(/^#+\s*/, "");
    }
  }

  // No frontmatter — return first non-empty line
  for (const line of lines) {
    if (line.trim() !== "") return line.trim();
  }

  return "Unknown Task";
}

export const CompactionSavePlugin = async ({ directory }) => {
  return {
    "experimental.session.compacting": async (_input, output) => {
      const activeDir = join(directory, ".ai/telamon/memory/work/active");

      if (!existsSync(activeDir)) {
        return;
      }

      const entries = readdirSync(activeDir, { withFileTypes: true });
      const subdirs = entries.filter((e) => e.isDirectory());

      for (const subdir of subdirs) {
        const itemDir = join(activeDir, subdir.name);
        const readmePath = join(itemDir, "README.md");

        if (!existsSync(readmePath)) {
          continue;
        }

        try {
          const readmeContent = readFileSync(readmePath, "utf8");
          const title = extractTitle(readmeContent);
          const timestamp = new Date().toISOString();

          const compactionContent = `---\ncompacted_at: ${timestamp}\n---\n\nCompaction occurred for task: ${title}\n`;

          writeFileSync(join(itemDir, "compaction.md"), compactionContent);

          output.context.push(`Active work item: ${subdir.name} — ${title}`);
        } catch {
          continue;
        }
      }
    },
  };
};

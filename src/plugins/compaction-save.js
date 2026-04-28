import { existsSync, readdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { extractTitle } from "./lib/readme-utils.js";

export const CompactionSavePlugin = async ({ directory }) => {
  return {
    "experimental.session.compacting": async (_input, output) => {
      const activeDir = join(directory, ".ai/telamon/memory/work/active");

      if (!existsSync(activeDir)) {
        return;
      }

      let entries;
      try {
        entries = readdirSync(activeDir, { withFileTypes: true });
      } catch {
        return;
      }

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

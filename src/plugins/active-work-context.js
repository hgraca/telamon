import { existsSync, readdirSync, readFileSync } from "fs";
import { join } from "path";
import { extractTitle } from "./lib/readme-utils.js";

const MAX_DESCRIPTION_CHARS = 200;

/**
 * Extracts a short description from lines after the title in a README.md.
 * Skips frontmatter, skips the title line, collects the first paragraph
 * (stops at the first empty line after collecting at least one line, or at
 * the next heading), and truncates to MAX_DESCRIPTION_CHARS.
 */
function extractDescription(content) {
  const lines = content.split("\n");
  let inFrontmatter = false;
  let frontmatterClosed = false;
  let titleFound = false;
  const descLines = [];

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

    if (inFrontmatter) continue;

    if (!frontmatterClosed && !titleFound) {
      // No frontmatter case — first non-empty line is title
      if (line !== "") {
        titleFound = true;
        continue;
      }
      continue;
    }

    if (frontmatterClosed && !titleFound) {
      if (line !== "") {
        titleFound = true;
        continue;
      }
      continue;
    }

    if (titleFound) {
      // Stop at next heading
      if (line.startsWith("#")) break;

      // Stop at paragraph break (empty line after collecting at least one line)
      if (line === "") {
        if (descLines.length > 0) break;
        continue;
      }

      descLines.push(line);
    }
  }

  const joined = descLines.join(" ");
  if (joined.length <= MAX_DESCRIPTION_CHARS) return joined;
  return joined.slice(0, MAX_DESCRIPTION_CHARS) + "...";
}

export const ActiveWorkContextPlugin = async ({ directory }) => {
  let injected = false;

  return {
    "tool.execute.before": async (input, output) => {
      if (injected) return;
      if (input.tool !== "bash") return;

      const activeDir = join(directory, ".ai/telamon/memory/work/active");

      if (!existsSync(activeDir)) {
        injected = true;
        return;
      }

      let entries;
      try {
        entries = readdirSync(activeDir, { withFileTypes: true });
      } catch {
        injected = true;
        return;
      }

      const subdirs = entries.filter((e) => e.isDirectory());

      const items = [];
      for (const subdir of subdirs) {
        const itemDir = join(activeDir, subdir.name);
        const readmePath = join(itemDir, "README.md");

        if (!existsSync(readmePath)) continue;

        try {
          const content = readFileSync(readmePath, "utf8");
          const title = extractTitle(content);
          const description = extractDescription(content);
          items.push({ name: subdir.name, title, description });
        } catch {
          continue;
        }
      }

      if (items.length === 0) {
        injected = true;
        return;
      }

      const itemLines = items
        .map((item) => {
          const desc = item.description ? `\n    ${item.description}` : "";
          return `  - ${item.name}: ${item.title}${desc}`;
        })
        .join("\n");

      const context =
        `[active-work-context] You have active work items in progress:\n${itemLines}\n\n` +
        `Please ask the user what they would like to do: continue an active task, archive it, or start something new.`;

      const escaped = context.replace(/'/g, "'\\''");
      output.args.command = `echo '${escaped}' && ` + output.args.command;
      injected = true;
    },
  };
};

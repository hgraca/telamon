/**
 * Shared README parsing utilities for opencode plugins.
 * Pure string operations — no filesystem access.
 */

/**
 * Extracts the title from a README.md with optional YAML frontmatter.
 * Returns the first non-empty line after the closing `---` of the frontmatter,
 * with any leading heading markers stripped.
 */
export function extractTitle(content) {
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
    if (line.trim() !== "") return line.trim().replace(/^#+\s*/, "");
  }

  return "Unknown Task";
}

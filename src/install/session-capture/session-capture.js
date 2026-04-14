// session-capture plugin
// Injects the session-capture skill into the compaction prompt so the model
// saves everything worth keeping to the Obsidian vault before context is lost.

import { readFileSync, existsSync } from "fs";
import { join } from "path";

export const SessionCapturePlugin = async ({ directory }) => {
  return {
    "experimental.session.compacting": async (input, output) => {
      const skillPath = join(
        directory,
        ".opencode/skills/session-capture/SKILL.md"
      );
      if (!existsSync(skillPath)) return;

      const skill = readFileSync(skillPath, "utf8");

      output.context.push(`## Pre-Compaction Memory Capture

Before generating the continuation summary, run the session-capture skill in full.
Do not skip or abbreviate it — compaction is the last chance to preserve session knowledge.

${skill}`);
    },
  };
};

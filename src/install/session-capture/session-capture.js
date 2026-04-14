// session-capture plugin
// Injects the session-capture skill into the compaction prompt so the model
// saves everything worth keeping to the Obsidian vault before context is lost.
//
// Watermark: reads .ai/adk/memory/thinking/.last-capture before each run and
// writes an updated one after, so the skill only processes content produced
// since the previous capture — preventing duplicate entries on repeat compactions.

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join, dirname } from "path";

const WATERMARK_PATH = ".ai/adk/memory/thinking/.last-capture";

export const SessionCapturePlugin = async ({ directory }) => {
  return {
    "experimental.session.compacting": async (input, output) => {
      const skillPath = join(
        directory,
        ".opencode/skills/session-capture/SKILL.md"
      );
      if (!existsSync(skillPath)) return;

      const skill = readFileSync(skillPath, "utf8");

      // Read existing watermark (if any)
      const watermarkFile = join(directory, WATERMARK_PATH);
      let lastCapture = null;
      if (existsSync(watermarkFile)) {
        try {
          lastCapture = JSON.parse(readFileSync(watermarkFile, "utf8"));
        } catch {
          // corrupt watermark — treat as first run
        }
      }

      // Write updated watermark now (before the model runs) so that if
      // compaction fires again before the model finishes, we don't double-run.
      const now = new Date().toISOString();
      mkdirSync(dirname(watermarkFile), { recursive: true });
      writeFileSync(watermarkFile, JSON.stringify({ timestamp: now }), "utf8");

      const sinceClause = lastCapture
        ? `**Only process content produced AFTER ${lastCapture.timestamp}** — everything before that timestamp was already captured in a previous run. Use \`git log --oneline --after="${lastCapture.timestamp}" --no-merges\` to scope commit history.`
        : `This is the first capture for this session — process all content.`;

      output.context.push(`## Pre-Compaction Memory Capture

Before generating the continuation summary, run the session-capture skill in full.
Do not skip or abbreviate it — compaction is the last chance to preserve session knowledge.

${sinceClause}

${skill}`);
    },
  };
};

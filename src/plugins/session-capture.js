// session-capture plugin
// Triggers the session-capture skill after the agent goes idle (session.idle),
// so learnings are promoted to the Obsidian vault and Ogham automatically
// after each completed work block — not just at compaction time.
//
// Throttle: only fires when at least MIN_CAPTURE_INTERVAL_MS have elapsed
// since the last capture. The watermark is written BEFORE the prompt is sent
// so that when the agent finishes the capture and fires session.idle again,
// the interval check skips it — preventing an infinite loop.
//
// Watermark is scoped to the git worktree directory name so concurrent agents
// in different worktrees track their own capture history independently.

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join, dirname, basename } from "path";

// Minimum time between automated captures. Must be longer than the time the
// agent takes to complete a capture run (typically < 5 min), with headroom.
const MIN_CAPTURE_INTERVAL_MS = 30 * 60 * 1000; // 30 minutes

function worktreeSlug(worktree, directory) {
  const raw = basename(worktree || directory || "default");
  return raw.replace(/[^a-z0-9_-]/gi, "-").toLowerCase();
}

export const SessionCapturePlugin = async ({ directory, worktree, client }) => {
  const slug = worktreeSlug(worktree, directory);
  const WATERMARK_REL = `.ai/adk/memory/thinking/.last-capture-${slug}.json`;

  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return;

      // Extract session ID — guard against different event shapes across versions
      const sessionId =
        event?.properties?.info?.id ||
        event?.properties?.sessionID ||
        event?.properties?.id;
      if (!sessionId) return;

      // Throttle: skip if last capture was recent
      const watermarkFile = join(directory, WATERMARK_REL);
      let lastCapture = null;
      if (existsSync(watermarkFile)) {
        try {
          lastCapture = JSON.parse(readFileSync(watermarkFile, "utf8"));
        } catch {
          // corrupt watermark — treat as first run
        }
      }

      const now = Date.now();
      if (lastCapture?.timestamp) {
        const elapsed = now - new Date(lastCapture.timestamp).getTime();
        if (elapsed < MIN_CAPTURE_INTERVAL_MS) return;
      }

      // Write watermark BEFORE sending the prompt so that when the agent
      // finishes the capture response and fires session.idle again, the
      // interval check above skips it — no infinite loop.
      const nowIso = new Date(now).toISOString();
      mkdirSync(dirname(watermarkFile), { recursive: true });
      writeFileSync(
        watermarkFile,
        JSON.stringify({ timestamp: nowIso, worktree: worktree || directory }),
        "utf8"
      );

      // Prompt the agent to run the session-capture skill.
      // At idle the agent still has full context and skills loaded, so we only
      // need a brief trigger — no need to inject the skill content here.
      try {
        await client.session.prompt({
          path: { id: sessionId },
          body: {
            parts: [
              {
                type: "text",
                text: "[ADK] Please run the session-capture skill now.",
              },
            ],
          },
        });
      } catch (err) {
        // Non-fatal. Roll back the watermark so the next idle can retry.
        console.error(
          "[session-capture] Failed to send capture prompt:",
          err?.message ?? err
        );
        if (lastCapture) {
          try {
            writeFileSync(watermarkFile, JSON.stringify(lastCapture), "utf8");
          } catch {}
        }
      }
    },
  };
};

import { appendFileSync, existsSync, mkdirSync } from "fs";
import { dirname, join } from "path";

/**
 * Diagnostic-only plugin: observes compaction-related events and appends
 * structured log lines to `.ai/telamon/memory/thinking/compaction-events.log`.
 *
 * Purpose: investigate suspected double-compaction runs by recording every
 * `experimental.session.compacting` and `experimental.compaction.autocontinue`
 * fire with timestamp, sessionID, event type, and (for autocontinue) overflow
 * flag.
 *
 * Behavioural contract: NO behaviour change. Returns nothing for compacting
 * (so `output.context` is left to other plugins); returns `{enabled: true}`
 * for autocontinue (the documented default per @opencode-ai/plugin SDK).
 */
export const CompactionObserverPlugin = async ({ directory }) => {
  const logPath = join(
    directory,
    ".ai/telamon/memory/thinking/compaction-events.log",
  );

  const append = (entry) => {
    try {
      const dir = dirname(logPath);
      if (!existsSync(dir)) {
        mkdirSync(dir, { recursive: true });
      }
      appendFileSync(logPath, JSON.stringify(entry) + "\n", "utf8");
    } catch {
      // Diagnostic-only: never let logging failures interfere with compaction.
    }
  };

  return {
    "experimental.session.compacting": async (input) => {
      append({
        ts: new Date().toISOString(),
        event: "session.compacting",
        sessionID: input?.sessionID ?? null,
      });
    },
    "experimental.compaction.autocontinue": async (input) => {
      append({
        ts: new Date().toISOString(),
        event: "compaction.autocontinue",
        sessionID: input?.sessionID ?? null,
        agent: input?.agent ?? null,
        model: input?.model ?? null,
        overflow: input?.overflow ?? null,
      });
      return { enabled: true };
    },
  };
};

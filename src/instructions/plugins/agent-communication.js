// agent-communication plugin
// Detects whether the last assistant message ends with a canonical terminal
// status marker on session.idle. Nudges the agent if no marker is found.
//
// Marker list authority: .opencode/skills/telamon/workflow/
//   agent-communication/SKILL.md lines 19–24
//
// Canonical markers (PLAN-ARCH-2026-05-06-001.md §3.5):
//   FINISHED!  |  BLOCKED:  |  NEEDS_INPUT:  |  PARTIAL:
//
// IMPORTANT: This file exports ONLY the plugin function. opencode's plugin
// loader iterates Object.values(mod) and throws "Plugin export is not a
// function" for any non-function export value (strings, numbers, RegExp).
// All helpers and constants live in agent-communication-helpers.js.

import { existsSync, writeFileSync, mkdirSync, unlinkSync } from "fs";
import { dirname } from "path";
import {
  NUDGE_PROMPT,
  MAX_COUNTER_ENTRIES,
  worktreeSlug,
  lockPath,
  isLockFresh,
  hasEnforcerTag,
  detectTerminalMarker,
  readCounter,
  writeCounter,
  loadConfig,
} from "./agent-communication-helpers.js";

// ─── AgentCommunicationPlugin ───────────────────────────────────────────────
// Plugin factory. Returns { event: async ({ event }) => ... }.
// PLAN-ARCH-2026-05-06-001.md §2, §6, §8.
// Only export: opencode loader rejects any non-function named export.
export const AgentCommunicationPlugin = async ({ directory, worktree, client }) => {
  return {
    event: async ({ event }) => {
      try {
        // 1. Event-type filter
        if (event.type !== "session.idle") return;

        // 2. Disabled gate (PLAN §2 step 2)
        const config = loadConfig(directory);
        if (!config.enabled) return;

        // 3. Agent-identity opt-out (PLAN §6)
        const agentId = event?.properties?.info?.agent;
        if (agentId && config.exempt_agents.includes(agentId)) return;

        // 4. Extract session ID (mirrors remember-session.js:45-49)
        const sessionId =
          event?.properties?.info?.id ||
          event?.properties?.sessionID ||
          event?.properties?.id;
        if (!sessionId) return;

        // 5. Fetch messages
        const { data: messages } = await client.session.messages({
          path: { id: sessionId },
        });

        // 6. Find last assistant message (PLAN §2 step 5)
        const lastAssistant = [...(messages ?? [])]
          .reverse()
          .find((m) => m.info?.role === "assistant");

        // 7. Fail-open if no assistant message found
        if (!lastAssistant) return;

        // 8. Detect marker
        const hasMarker = detectTerminalMarker(lastAssistant);
        if (hasMarker) {
          // Reset counter for this session — recovery confirmed
          const counter = readCounter(directory, worktree);
          if (counter[sessionId]) {
            delete counter[sessionId];
            writeCounter(directory, worktree, counter);
          }
          return;
        }

        // 9. Last-message tag check — skip if our own nudge triggered this idle
        if (hasEnforcerTag(messages ?? [])) return;

        // 10. Lock file check — skip if a fresh lock exists (in-flight nudge)
        const slug = worktreeSlug(worktree, directory);
        const lock = lockPath(slug, directory);
        if (isLockFresh(lock, Date.now())) return;

        // 11. Attempt counter
        const counter = readCounter(directory, worktree);
        const entry = counter[sessionId] ?? { attempts: 0, lastNudge: null };

        if (entry.attempts >= config.max_attempts) {
          process.stderr.write(
            `[agent-communication] Session ${sessionId} exceeded max nudge attempts (${entry.attempts}) — stopping. Human review needed.\n`
          );
          return;
        }

        // 12. Acquire lock before prompt
        try {
          mkdirSync(dirname(lock), { recursive: true });
          writeFileSync(lock, JSON.stringify({ started: new Date().toISOString() }), "utf8");
        } catch (lockErr) {
          process.stderr.write(`[agent-communication] Failed to write lock file: ${lockErr?.message ?? lockErr}\n`);
        }

        // 13. Send nudge; release lock in finally
        try {
          await client.session.prompt({
            path: { id: sessionId },
            body: {
              parts: [
                {
                  type: "text",
                  text: NUDGE_PROMPT,
                  synthetic: true,
                  metadata: { hidden: true, source: "agent-communication" },
                },
              ],
            },
          });
        } finally {
          try {
            if (existsSync(lock)) unlinkSync(lock);
          } catch (unlinkErr) {
            process.stderr.write(`[agent-communication] Failed to delete lock file: ${unlinkErr?.message ?? unlinkErr}\n`);
          }
        }

        // 14. Increment counter
        counter[sessionId] = { attempts: entry.attempts + 1, lastNudge: new Date().toISOString() };

        if (Object.keys(counter).length > MAX_COUNTER_ENTRIES) {
          const sorted = Object.entries(counter).sort((a, b) => {
            const ta = a[1].lastNudge ? new Date(a[1].lastNudge).getTime() : 0;
            const tb = b[1].lastNudge ? new Date(b[1].lastNudge).getTime() : 0;
            return ta - tb;
          });
          while (sorted.length > MAX_COUNTER_ENTRIES) sorted.shift();
          writeCounter(directory, worktree, Object.fromEntries(sorted));
        } else {
          writeCounter(directory, worktree, counter);
        }
      } catch (err) {
        process.stderr.write(`[agent-communication] Error in event handler: ${err?.message ?? err}\n`);
      }
    },
  };
};

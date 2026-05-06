// remember-session plugin
// Triggers the remember_session skill after the agent goes idle (session.idle),
// so learnings are promoted to brain/ notes automatically
// after each completed work block — not just at compaction time.
//
// Loop prevention uses two mechanisms:
//   B) Lock file with 10-min TTL — prevents re-entrancy while capture is running
//   C) Last-message check — if the last user message is our own capture prompt,
//      skip (the idle event was fired by the capture response completing)
//
// Content deduplication is handled by the skill itself via the watermark file
// (.last-capture-<slug>.json) — if nothing new happened since last capture,
// the skill exits quickly.
//
// Worktree-scoped so concurrent agents in different worktrees track independently.

import { readFileSync, writeFileSync, existsSync, mkdirSync, unlinkSync } from "fs";
import { join, dirname, basename } from "path";

const LOCK_TTL_MS = 10 * 60 * 1000; // 10 minutes
const STALL_FLAG_TTL_MS = 6 * 60 * 1000; // duplicated per ADR M-ARCH-034 (= LOCK_TTL_MS_enforcer + GRACE_MS)
const CAPTURE_PROMPT_TEXT =
  "[Telamon] Please load the `telamon.remember_session` skill and run it now. This is an automated idle capture — do not report results to the user.";

function worktreeSlug(worktree, directory) {
  const raw = basename(worktree || directory || "default");
  return raw.replace(/[^a-z0-9_-]/gi, "-").toLowerCase();
}

// Duplicated from status-marker-enforcer.js per ADR M-ARCH-034 (no shared module).
function readMaxAttemptsFromConfig(directory) {
  const configPath = join(directory, ".telamon.jsonc");
  if (!existsSync(configPath)) return 2;
  try {
    const raw = readFileSync(configPath, "utf8");
    const parsed = JSON.parse(raw);
    return parsed?.status_marker_enforcer?.max_attempts ?? 2;
  } catch {
    return 2;
  }
}

// --- Known upstream bug: prefill error (opencode #13768) ---
// Patched via opencode_patches in .telamon.jsonc (PR #14772).
// This regex is kept for the inner catch block only — if the patch
// hasn't been applied yet, we suppress our own re-logging of the error.
const PREFILL_RE = /assistant message prefill|must end with a user message/i;

export const RememberSessionPlugin = async ({ directory, worktree, client }) => {
  const slug = worktreeSlug(worktree, directory);
  const LOCK_REL = `.ai/telamon/memory/thinking/.capture-lock-${slug}`;
  const lockFile = join(directory, LOCK_REL);

  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return;

      // Extract session ID — guard against different event shapes across versions
      const sessionId =
        event?.properties?.info?.id ||
        event?.properties?.sessionID ||
        event?.properties?.id;
      if (!sessionId) return;

      // --- Option B: Lock file with TTL ---
      // If a capture is currently in progress (lock exists and is fresh), skip.
      if (existsSync(lockFile)) {
        try {
          const lock = JSON.parse(readFileSync(lockFile, "utf8"));
          const age = Date.now() - new Date(lock.started).getTime();
          if (age < LOCK_TTL_MS) return; // lock is fresh → capture in progress
          // Stale lock (> 10 min) → ignore it, proceed
        } catch {
          // Corrupt lock file — remove and proceed
        }
      }

      // NEW: respect status-enforcer's stall-flag — don't capture an incomplete turn.
      const stallFlag = join(directory, `.ai/telamon/memory/thinking/.status-enforcer-stall-${slug}.json`);
      if (existsSync(stallFlag)) {
        try {
          const f = JSON.parse(readFileSync(stallFlag, "utf8"));
          const age = Date.now() - new Date(f.started).getTime();
          const max = readMaxAttemptsFromConfig(directory);
          if (age < STALL_FLAG_TTL_MS && (f.attempt ?? 0) < max) return;
        } catch { /* corrupt flag → fall through and capture */ }
      }

      // --- Option C: Last-message check ---      // If the last user message in this session is our own capture prompt,
      // this idle was fired by the capture response completing → skip.
      try {
        const { data: messages } = await client.session.messages({
          path: { id: sessionId },
        });
        if (messages && messages.length > 0) {
          // Find the last user message
          const lastUserMsg = [...messages]
            .reverse()
            .find((m) => m.info?.role === "user");
          if (lastUserMsg) {
            // Check if any text part matches our prompt
            const parts = lastUserMsg.parts || [];
            const isOurPrompt = parts.some(
              (p) =>
                p.type === "text" && p.text && p.text.includes("[Telamon]")
            );
            if (isOurPrompt) return; // capture just finished → skip
          }
        }
      } catch {
        // If we can't read messages, proceed anyway — the lock guards re-entrancy
      }

      // --- Acquire lock ---
      mkdirSync(dirname(lockFile), { recursive: true });
      writeFileSync(
        lockFile,
        JSON.stringify({
          started: new Date().toISOString(),
          worktree: worktree || directory,
        }),
        "utf8"
      );

      // --- Send capture prompt ---
      try {
        await client.session.prompt({
          path: { id: sessionId },
          body: {
            parts: [
              {
                type: "text",
                text: CAPTURE_PROMPT_TEXT,
                synthetic: true,
                metadata: { hidden: true, source: "remember-session-plugin" },
              },
            ],
          },
        });
      } catch (err) {
        const msg = err?.message ?? String(err);
        // Prefill errors = upstream bug (opencode #13768), patched via PR #14772.
        // If the patch isn't applied, suppress our own logging — capture still succeeded.
        if (!PREFILL_RE.test(msg)) {
          console.error(
            "[remember-session] Failed to send capture prompt:",
            msg
          );
        }
      } finally {
        // Release lock after prompt completes (success or failure).
        // The prompt() call is synchronous (waits for agent response),
        // so by this point the capture has finished.
        try {
          if (existsSync(lockFile)) unlinkSync(lockFile);
        } catch {}
      }
    },
  };
};

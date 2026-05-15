// auto-recover plugin
// Detects mid-stream provider errors (MidStreamFallbackError, APIConnectionError,
// OpenAIException, transient upstream failures) on `session.error` and auto-injects
// a "continue" prompt so the agent resumes without user interaction.
//
// Design constraints (mirrors remember-session.js / agent-communication.js):
//   - Worktree-scoped state (lock + attempt counter) — concurrent agents don't collide.
//   - Lock file with TTL prevents recovery storms when the provider flaps.
//   - Per-session attempt counter with TTL caps total recovery attempts so a
//     truly broken session eventually surfaces to the human instead of looping.
//   - No shared module imports — each plugin is self-contained per ADR M-ARCH-034.
//
// Recovery prompt is delivered as a synthetic hidden message tagged [Telamon-AutoRecover]
// so downstream tools (remember-session, agent-communication) can detect and skip it.

import {
  existsSync,
  mkdirSync,
  readFileSync,
  unlinkSync,
  writeFileSync,
} from "fs";
import { basename, dirname, join } from "path";

// ─── Tunables ─────────────────────────────────────────────────────────────────
const LOCK_TTL_MS = 2 * 60 * 1000;          // 2 min — short, errors clear fast
const COUNTER_TTL_MS = 30 * 60 * 1000;       // 30 min window per session
const DEFAULT_MAX_ATTEMPTS = 3;              // bail after 3 recoveries / window
const COOLDOWN_BASE_MS = 5_000;              // 5s, doubles each attempt

// ─── Recovery prompt ──────────────────────────────────────────────────────────
const RECOVERY_PROMPT_TEXT =
  "[Telamon-AutoRecover] The previous response was interrupted by a transient " +
  "provider error (mid-stream connection failure). Resume the task you were " +
  "working on from where it left off. Do not restart from scratch and do not " +
  "explain the error — continue silently with the next concrete step.";

// ─── Error pattern (case-insensitive) ─────────────────────────────────────────
// These are the substrings we treat as transient and recoverable.
// Anything else is left alone (the human should see it).
// Includes upstream opencode bug #13768 (assistant message prefill / must end
// with a user message) — see latent/gotchas.md L140. Treated as transient so
// the synthetic user-message recovery prompt naturally satisfies the
// "conversation must end with a user message" constraint.
const TRANSIENT_RE =
  /(MidStreamFallbackError|APIConnectionError|OpenAIException|ECONNRESET|ETIMEDOUT|socket hang up|stream (?:closed|aborted)|fetch failed|503 |502 |504 |overloaded|assistant message prefill|must end with a user message|SSE read timed out)/i;

// ─── worktreeSlug ─────────────────────────────────────────────────────────────
// Duplicated from remember-session.js per ADR M-ARCH-034 (no shared module).
function worktreeSlug(worktree, directory) {
  const raw = basename(worktree || directory || "default");
  return raw.replace(/[^a-z0-9_-]/gi, "-").toLowerCase();
}

// ─── Config reader ────────────────────────────────────────────────────────────
function readMaxAttemptsFromConfig(directory) {
  const configPath = join(directory, ".telamon.jsonc");
  if (!existsSync(configPath)) return DEFAULT_MAX_ATTEMPTS;
  try {
    const raw = readFileSync(configPath, "utf8");
    // Strip line comments before parsing as JSON
    const stripped = raw.replace(/^\s*\/\/.*$/gm, "");
    const parsed = JSON.parse(stripped);
    return parsed?.auto_recover?.max_attempts ?? DEFAULT_MAX_ATTEMPTS;
  } catch {
    return DEFAULT_MAX_ATTEMPTS;
  }
}

// ─── Counter file helpers ─────────────────────────────────────────────────────
function loadCounter(counterPath) {
  if (!existsSync(counterPath)) return {};
  try {
    return JSON.parse(readFileSync(counterPath, "utf8"));
  } catch {
    return {};
  }
}

function saveCounter(counterPath, data) {
  mkdirSync(dirname(counterPath), { recursive: true });
  writeFileSync(counterPath, JSON.stringify(data, null, 2), "utf8");
}

function pruneCounter(data) {
  const now = Date.now();
  const out = {};
  for (const [k, v] of Object.entries(data)) {
    if (v && typeof v.lastAt === "number" && now - v.lastAt < COUNTER_TTL_MS) {
      out[k] = v;
    }
  }
  return out;
}

export const AutoRecoverPlugin = async ({ directory, worktree, client }) => {
  const slug = worktreeSlug(worktree, directory);
  const lockFile = join(
    directory,
    `.ai/telamon/memory/thinking/.auto-recover-lock-${slug}`,
  );
  const counterFile = join(
    directory,
    `.ai/telamon/memory/thinking/.auto-recover-attempts-${slug}.json`,
  );

  return {
    event: async ({ event }) => {
      if (event.type !== "session.error") return;

      // Extract session ID — guard against shape variation across opencode versions
      const sessionId =
        event?.properties?.sessionID ||
        event?.properties?.info?.id ||
        event?.properties?.id;
      if (!sessionId) return;

      // Extract error message from any plausible location
      const errMsg =
        event?.properties?.error?.message ||
        event?.properties?.error?.data?.message ||
        event?.properties?.message ||
        (typeof event?.properties?.error === "string"
          ? event.properties.error
          : "") ||
        "";

      if (!TRANSIENT_RE.test(errMsg)) return; // not a recoverable error class

      // ── Lock check: are we already recovering this worktree? ──────────────
      if (existsSync(lockFile)) {
        try {
          const lock = JSON.parse(readFileSync(lockFile, "utf8"));
          const age = Date.now() - new Date(lock.started).getTime();
          if (age < LOCK_TTL_MS) return; // recovery in flight
        } catch {
          // corrupt lock — fall through and overwrite
        }
      }

      // ── Attempt counter ────────────────────────────────────────────────────
      const max = readMaxAttemptsFromConfig(directory);
      let counter = pruneCounter(loadCounter(counterFile));
      const entry = counter[sessionId] ?? { count: 0, lastAt: 0 };
      if (entry.count >= max) {
        // Surfaced to the human — do NOT keep trying. Reset on next non-error turn.
        console.warn(
          `[auto-recover] session ${sessionId} exceeded max recovery attempts ` +
            `(${entry.count}/${max}); leaving for human review.`,
        );
        return;
      }

      // Exponential backoff between attempts within the same session
      const sinceLast = Date.now() - entry.lastAt;
      const cooldown = COOLDOWN_BASE_MS * Math.pow(2, entry.count);
      if (entry.lastAt > 0 && sinceLast < cooldown) return;

      // ── Acquire lock ───────────────────────────────────────────────────────
      mkdirSync(dirname(lockFile), { recursive: true });
      writeFileSync(
        lockFile,
        JSON.stringify({
          started: new Date().toISOString(),
          sessionId,
          attempt: entry.count + 1,
        }),
        "utf8",
      );

      // ── Bump counter ───────────────────────────────────────────────────────
      counter[sessionId] = { count: entry.count + 1, lastAt: Date.now() };
      saveCounter(counterFile, counter);

      // ── Send recovery prompt ───────────────────────────────────────────────
      try {
        // Brief pause — let any in-flight cleanup settle
        await new Promise((r) => setTimeout(r, 1500));

        await client.session.prompt({
          path: { id: sessionId },
          body: {
            parts: [
              {
                type: "text",
                text: RECOVERY_PROMPT_TEXT,
                synthetic: true,
                metadata: {
                  hidden: true,
                  source: "auto-recover-plugin",
                  attempt: entry.count + 1,
                  maxAttempts: max,
                  errorPreview: errMsg.slice(0, 200),
                },
              },
            ],
          },
        });
      } catch (err) {
        console.error(
          "[auto-recover] failed to send recovery prompt:",
          err?.message ?? String(err),
        );
      } finally {
        try {
          if (existsSync(lockFile)) unlinkSync(lockFile);
        } catch {
          /* ignore */
        }
      }
    },
  };
};

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
// Task 2 scope: idle hook + message fetch + marker detection.
// Tasks 3+: nudge prompt, lock file, attempt counter, tag string, ordering.

import { readFileSync, existsSync, writeFileSync, mkdirSync, unlinkSync } from "fs";
import { join, basename, dirname } from "path";

// ─── Marker regex ─────────────────────────────────────────────────────────────
// Constructed from the 4 canonical markers in agent-communication/SKILL.md lines 19–24.
// Line-anchored; no multiline flag — we test one extracted line at a time.
export const MARKER_RE = /^(FINISHED!|BLOCKED:|NEEDS_INPUT:|PARTIAL:)/;

// ─── Nudge prompt ─────────────────────────────────────────────────────────────
// Delivered as a synthetic hidden message when no terminal marker is detected.
// Numbered checklist format per M-FLOW-072. All four markers verbatim (PDR guard).
export const NUDGE_PROMPT = `[Telamon-StatusEnforcer] Your last response did not end with a required status marker. End your next response with exactly one of the following markers on its own line:

1. FINISHED! — work is genuinely complete
2. BLOCKED: <reason> — cannot proceed without external action
3. NEEDS_INPUT: <question> — needs clarification from the human before continuing
4. PARTIAL: <summary> — work is incomplete; a fresh session must resume from this point

Do NOT default to FINISHED! if the work is not actually complete — PARTIAL: is the honest answer for incomplete work.`;

// ─── Default config ───────────────────────────────────────────────────────────
const DEFAULT_EXEMPT_AGENTS = ["repomix-agent", "qmd"];

// ─── Attempt counter constants ────────────────────────────────────────────────
export const MAX_COUNTER_ENTRIES = 100;
export const COUNTER_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

// ─── Lock file constants ───────────────────────────────────────────────────────
export const LOCK_TTL_MS = 5 * 60 * 1000; // 5 minutes

// ─── Stall-flag constants ─────────────────────────────────────────────────────
export const GRACE_MS = 60_000; // 60 seconds
export const STALL_FLAG_TTL_MS = LOCK_TTL_MS + GRACE_MS; // = 360_000 ms (6 min)

// ─── worktreeSlug ─────────────────────────────────────────────────────────────
// Duplicated from src/plugins/remember-session.js per ADR "Duplicate worktreeSlug function".
// Do NOT import — each plugin is self-contained.
export function worktreeSlug(worktree, directory) {
  const raw = basename(worktree || directory || "default");
  return raw.replace(/[^a-z0-9_-]/gi, "-").toLowerCase();
}

// ─── Lock file path ───────────────────────────────────────────────────────────
export function lockPath(slug, directory) {
  return join(directory, `.ai/telamon/memory/thinking/.agent-communication-lock-${slug}`);
}

// ─── Stall-flag path ──────────────────────────────────────────────────────────
export function stallFlagPath(slug, directory) {
  return join(directory, `.ai/telamon/memory/thinking/.agent-communication-stall-${slug}.json`);
}

// ─── writeStallFlag ───────────────────────────────────────────────────────────
export function writeStallFlag(worktree, directory, sessionId, attempt) {
  const slug = worktreeSlug(worktree, directory);
  const filePath = stallFlagPath(slug, directory);
  try {
    mkdirSync(dirname(filePath), { recursive: true });
    writeFileSync(filePath, JSON.stringify({ sessionId, started: new Date().toISOString(), attempt }), "utf8");
  } catch (err) {
    process.stderr.write(`[agent-communication] Failed to write stall-flag: ${err?.message ?? err}\n`);
  }
}

// ─── clearStallFlag ───────────────────────────────────────────────────────────
export function clearStallFlag(worktree, directory) {
  const slug = worktreeSlug(worktree, directory);
  const filePath = stallFlagPath(slug, directory);
  try {
    if (existsSync(filePath)) unlinkSync(filePath);
  } catch (err) {
    process.stderr.write(`[agent-communication] Failed to clear stall-flag: ${err?.message ?? err}\n`);
  }
}

// ─── isLockFresh ──────────────────────────────────────────────────────────────
// Returns true if the lock file at `path` was written within LOCK_TTL_MS of `now`.
export function isLockFresh(path, now) {
  try {
    if (!existsSync(path)) return false;
    const raw = readFileSync(path, "utf8");
    const lock = JSON.parse(raw);
    const age = (now ?? Date.now()) - new Date(lock.started).getTime();
    return age < LOCK_TTL_MS;
  } catch {
    return false;
  }
}

// ─── hasEnforcerTag ───────────────────────────────────────────────────────────
// Returns true if the last user message in `messages` contains [Telamon-StatusEnforcer].
// Uses canonical SDK shape: m.info.role and m.parts[i].text.
export function hasEnforcerTag(messages) {
  const lastUserMsg = [...(messages ?? [])].reverse().find(function (m) {
    return m.info?.role === "user";
  });
  if (!lastUserMsg) return false;
  const parts = lastUserMsg.parts ?? [];
  return parts.some(function (p) {
    return typeof p.text === "string" && p.text.includes("[Telamon-StatusEnforcer]");
  });
}

// ─── Counter file path ────────────────────────────────────────────────────────
function counterFilePath(directory, slug) {
  return join(directory, ".ai/telamon/memory/thinking", `.agent-communication-counter-${slug}.json`);
}

// ─── pruneCounter ─────────────────────────────────────────────────────────────
// Pure function. Removes entries older than COUNTER_TTL_MS.
// `now` should be a Date or ISO string.
export function pruneCounter(counter, now) {
  const nowMs = now
    ? (now instanceof Date ? now.getTime() : new Date(now).getTime())
    : Date.now();
  const result = {};
  for (const [key, entry] of Object.entries(counter)) {
    if (!entry.lastNudge) {
      result[key] = entry;
      continue;
    }
    const age = nowMs - new Date(entry.lastNudge).getTime();
    if (age < COUNTER_TTL_MS) {
      result[key] = entry;
    }
  }
  // Evict oldest entries if over limit
  if (Object.keys(result).length > MAX_COUNTER_ENTRIES) {
    const sorted = Object.entries(result).sort((a, b) => {
      const ta = a[1].lastNudge ? new Date(a[1].lastNudge).getTime() : 0;
      const tb = b[1].lastNudge ? new Date(b[1].lastNudge).getTime() : 0;
      return ta - tb;
    });
    while (sorted.length > MAX_COUNTER_ENTRIES) sorted.shift();
    return Object.fromEntries(sorted);
  }
  return result;
}

// ─── readCounter ──────────────────────────────────────────────────────────────
// Reads counter from disk, prunes stale entries, returns {} on missing/malformed.
export function readCounter(directory, worktree) {
  const slug = worktreeSlug(worktree, directory);
  const filePath = counterFilePath(directory, slug);
  try {
    if (!existsSync(filePath)) return {};
    const raw = readFileSync(filePath, "utf8");
    const parsed = JSON.parse(raw);
    return pruneCounter(parsed, new Date());
  } catch {
    return {};
  }
}

// ─── writeCounter ─────────────────────────────────────────────────────────────
// Writes counter to disk. Creates parent dirs if needed.
export function writeCounter(directory, worktree, counter) {
  const slug = worktreeSlug(worktree, directory);
  const filePath = counterFilePath(directory, slug);
  try {
    mkdirSync(dirname(filePath), { recursive: true });
    writeFileSync(filePath, JSON.stringify(counter, null, 2), "utf8");
  } catch (err) {
    process.stderr.write(`[agent-communication] Failed to write counter file: ${err?.message ?? err}\n`);
  }
}

// ─── Config loader ────────────────────────────────────────────────────────────
function loadConfig(directory) {
  const configPath = join(directory, ".telamon.jsonc");
  if (!existsSync(configPath)) {
    return { enabled: true, exempt_agents: DEFAULT_EXEMPT_AGENTS, max_attempts: 2 };
  }
  try {
    const raw = readFileSync(configPath, "utf8");
    const parsed = JSON.parse(raw);
    const sme = parsed?.agent_communication ?? {};
    return {
      enabled: sme.enabled !== false,
      exempt_agents: sme.exempt_agents ?? DEFAULT_EXEMPT_AGENTS,
      max_attempts: sme.max_attempts ?? 2,
    };
  } catch {
    return { enabled: true, exempt_agents: DEFAULT_EXEMPT_AGENTS, max_attempts: 2 };
  }
}

// ─── Strip trailing fenced code block ─────────────────────────────────────────
// PLAN §5: remove a single trailing ```...``` block before marker analysis.
function stripTrailingFencedBlock(text) {
  // Match a fenced block at the end of the string (with optional trailing whitespace)
  const fenceRe = /```[\s\S]*?```\s*$/;
  return text.replace(fenceRe, "");
}

// ─── detectTerminalMarker ─────────────────────────────────────────────────────
// Pure function. Returns true if the message ends with a canonical marker,
// or if the message should be treated as fail-open (empty, user role, etc.).
// PLAN §5 pseudocode.
export function detectTerminalMarker(msg) {
  // Fail-open for user messages (PLAN §2 step 5 — caller filters by role,
  // but if called directly with a user message, treat as fail-open).
  if (msg?.info?.role === "user") return true;

  // Extract text from parts
  const parts = msg?.parts ?? [];
  const text = parts
    .filter((p) => p.type === "text")
    .map((p) => p.text)
    .join("");

  // Strip trailing fenced code block (PLAN §5)
  const stripped = stripTrailingFencedBlock(text);

  // Trim trailing whitespace
  const trimmed = stripped.trimEnd();

  // Fail-open on empty text (PLAN §5 edge-case)
  if (trimmed === "") return true;

  // Split on newlines, find last non-empty line
  const lines = trimmed.split("\n");
  let lastLine = "";
  for (let i = lines.length - 1; i >= 0; i--) {
    if (lines[i].trim() !== "") {
      lastLine = lines[i];
      break;
    }
  }

  if (lastLine === "") return true; // fail-open

  return MARKER_RE.test(lastLine);
}

// ─── AgentCommunicationPlugin ───────────────────────────────────────────────
// Plugin factory. Returns { event: async ({ event }) => ... }.
// PLAN-ARCH-2026-05-06-001.md §2, §6, §8.
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
        // Use m.info?.role with optional chaining (gotchas.md L1022)
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
          // Clear stall-flag — recovery confirmed, remember-session may capture
          clearStallFlag(worktree, directory);
          return;
        }

        // 9. Last-message tag check (Task 5) — skip if our own nudge triggered this idle
        if (hasEnforcerTag(messages ?? [])) return;

        // 10. Lock file check (Task 5) — skip if a fresh lock exists (in-flight nudge)
        const slug = worktreeSlug(worktree, directory);
        const lock = lockPath(slug, directory);
        if (isLockFresh(lock, Date.now())) return;

        // 11. Attempt counter (Task 4)
        const counter = readCounter(directory, worktree);
        const entry = counter[sessionId] ?? { attempts: 0, lastNudge: null };

        if (entry.attempts >= config.max_attempts) {
          process.stderr.write(
            `[agent-communication] Session ${sessionId} exceeded max nudge attempts (${entry.attempts}) — stopping. Human review needed.\n`
          );
          // Clear stall-flag so remember-session can capture the stalled session for human review
          clearStallFlag(worktree, directory);
          return;
        }

        // 12. Acquire lock before prompt (Task 5)
        try {
          mkdirSync(dirname(lock), { recursive: true });
          writeFileSync(lock, JSON.stringify({ started: new Date().toISOString() }), "utf8");
        } catch (lockErr) {
          process.stderr.write(`[agent-communication] Failed to write lock file: ${lockErr?.message ?? lockErr}\n`);
        }

        // 13. Send nudge; release lock in finally (Task 5)
        try {
          // Write stall-flag before prompt so remember-session defers capture (Task 6)
          writeStallFlag(worktree, directory, sessionId, entry.attempts + 1);
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

        // Eviction: if over limit, drop oldest lastNudge entry
        if (Object.keys(counter).length > MAX_COUNTER_ENTRIES) {
          const sorted = Object.entries(counter).sort((a, b) => {
            const ta = a[1].lastNudge ? new Date(a[1].lastNudge).getTime() : 0;
            const tb = b[1].lastNudge ? new Date(b[1].lastNudge).getTime() : 0;
            return ta - tb;
          });
          while (sorted.length > MAX_COUNTER_ENTRIES) {
            sorted.shift();
          }
          const evicted = Object.fromEntries(sorted);
          writeCounter(directory, worktree, evicted);
        } else {
          writeCounter(directory, worktree, counter);
        }
      } catch (err) {
        process.stderr.write(`[agent-communication] Error in event handler: ${err?.message ?? err}\n`);
      }
    },
  };
};

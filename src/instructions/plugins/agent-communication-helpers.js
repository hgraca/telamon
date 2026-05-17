// agent-communication-helpers.js
// Pure helpers and constants extracted from agent-communication.js so that
// the plugin file can export ONLY the plugin function (opencode's plugin loader
// iterates Object.values(mod) and throws "Plugin export is not a function" for
// any non-function export value).
//
// Tests import from this file; the plugin imports from this file too.

import { readFileSync, existsSync, writeFileSync, mkdirSync } from "fs";
import { join, basename, dirname } from "path";

// ─── Marker regex ─────────────────────────────────────────────────────────────
export const MARKER_RE = /^(FINISHED!|BLOCKED:|NEEDS_INPUT:|PARTIAL:)/;

// ─── Nudge prompt ─────────────────────────────────────────────────────────────
export const NUDGE_PROMPT = `[Telamon-StatusEnforcer] Your last response did not end with a required status marker. End your next response with exactly one of the following markers on its own line:

1. FINISHED! — work is genuinely complete
2. BLOCKED: <reason> — cannot proceed without external action
3. NEEDS_INPUT: <question> — needs clarification from the human before continuing
4. PARTIAL: <summary> — work is incomplete; a fresh session must resume from this point

Do NOT default to FINISHED! if the work is not actually complete — PARTIAL: is the honest answer for incomplete work.`;

// ─── Attempt counter constants ────────────────────────────────────────────────
export const MAX_COUNTER_ENTRIES = 100;
export const COUNTER_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

// ─── Lock file constants ───────────────────────────────────────────────────────
export const LOCK_TTL_MS = 5 * 60 * 1000; // 5 minutes

// ─── worktreeSlug ─────────────────────────────────────────────────────────────
export function worktreeSlug(worktree, directory) {
  const raw = basename(worktree || directory || "default");
  return raw.replace(/[^a-z0-9_-]/gi, "-").toLowerCase();
}

// ─── Lock file path ───────────────────────────────────────────────────────────
export function lockPath(slug, directory) {
  return join(directory, `.ai/telamon/memory/thinking/.agent-communication-lock-${slug}`);
}

// ─── isLockFresh ──────────────────────────────────────────────────────────────
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
export function counterFilePath(directory, slug) {
  return join(directory, ".ai/telamon/memory/thinking", `.agent-communication-counter-${slug}.json`);
}

// ─── pruneCounter ─────────────────────────────────────────────────────────────
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

// ─── Strip trailing fenced code block ─────────────────────────────────────────
export function stripTrailingFencedBlock(text) {
  const fenceRe = /```[\s\S]*?```\s*$/;
  return text.replace(fenceRe, "");
}

// ─── detectTerminalMarker ─────────────────────────────────────────────────────
export function detectTerminalMarker(msg) {
  if (msg?.info?.role === "user") return true;
  const parts = msg?.parts ?? [];
  const text = parts
    .filter((p) => p.type === "text")
    .map((p) => p.text)
    .join("");
  const stripped = stripTrailingFencedBlock(text);
  const trimmed = stripped.trimEnd();
  if (trimmed === "") return true;
  const lines = trimmed.split("\n");
  let lastLine = "";
  for (let i = lines.length - 1; i >= 0; i--) {
    if (lines[i].trim() !== "") {
      lastLine = lines[i];
      break;
    }
  }
  if (lastLine === "") return true;
  return MARKER_RE.test(lastLine);
}

// ─── Default config ───────────────────────────────────────────────────────────
export const DEFAULT_EXEMPT_AGENTS = ["repomix-agent", "qmd"];

// ─── Config loader ────────────────────────────────────────────────────────────
export function loadConfig(directory) {
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

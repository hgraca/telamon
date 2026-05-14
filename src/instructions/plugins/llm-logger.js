// llm-logger plugin
//
// Logs every LLM message (user request and assistant response) to disk —
// one file per message. Uses two hooks (both stable in v1.14.50):
//   - `chat.message`     → captures the user message at submit time
//   - `event` (filtered) → captures the assistant message on completion
//                          (event.type === "message.updated" with
//                          info.role === "assistant" and info.time.completed)
//
// File layout:
//   .ai/telamon/logs/llm-logger/<YYYYMMDDHHMMSS>-<sessionID>/
//     <timestamp>-<seq>-<role>-<messageID>.json
//
// The directory is gitignored via `.ai/telamon` — no risk of leaking prompts
// or responses into version control.
//
// Why the `event` hook for assistant capture?
//   `chat.message` only fires for user messages (input.role is implicit
//   "user"; output.message is the user message just submitted). To capture
//   the assistant response we listen for `message.updated` events and
//   fetch the full message+parts via `client.session.message(...)` once
//   `info.time.completed` is set. Multiple `message.updated` events fire
//   per message (one per part-append, plus completion), so we dedup by
//   messageID via `loggedAssistantIds`.
//
// IMPORTANT: This file MUST export ONLY the plugin factory.
// opencode v1.14.50's plugin loader treats every named export as a plugin
// factory; extra named exports (like a free-standing `_resetState`) cause
// the hook chain to throw `TypeError: undefined is not an object
// (evaluating 'H[W]')` at trigger time. Helpers stay module-internal.
// The factory itself carries `_resetState` as a property so tests can
// reset shared module state without adding a second export.

import { writeFileSync, mkdirSync, existsSync } from "fs";
import { join } from "path";

const sessionCreatedAt = new Map();
const loggedAssistantIds = new Set();
let fileCounter = 0;

function formatTimestamp(ts) {
  const d = new Date(ts);
  const pad = (n) => String(n).padStart(2, "0");
  return (
    `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}` +
    `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  );
}

function writeLog(baseDir, sessionID, filename, data) {
  let createdAt = sessionCreatedAt.get(sessionID);
  if (!createdAt) {
    createdAt = Date.now();
    sessionCreatedAt.set(sessionID, createdAt);
  }
  const folderName = `${formatTimestamp(createdAt)}-${sessionID}`;
  const dir = join(baseDir, folderName);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  const path = join(dir, filename);
  try {
    writeFileSync(path, JSON.stringify(data, null, 2), "utf8");
  } catch (err) {
    process.stderr.write(
      `[llm-logger] Failed to write ${path}: ${err?.message ?? err}\n`,
    );
  }
}

function writeMessageLog(baseDir, sessionID, messageID, role, message, parts, extra) {
  const roleLabel =
    role === "user" ? "request" : role === "assistant" ? "response" : role || "unknown";
  const ts = Date.now();
  const seq = ++fileCounter;
  const filename = `${ts}-${seq}-${roleLabel}-${messageID}.json`;

  writeLog(baseDir, sessionID, filename, {
    type: "chat.message",
    sessionID,
    messageID,
    agent: extra?.agent ?? message?.agent,
    model:
      extra?.model ??
      (message?.providerID && message?.modelID
        ? { providerID: message.providerID, modelID: message.modelID }
        : undefined),
    variant: extra?.variant,
    role,
    timestamp: new Date(ts).toISOString(),
    message: {
      id: message?.id,
      role: message?.role,
      agent: message?.agent,
      modelID: message?.modelID,
      providerID: message?.providerID,
      cost: message?.cost,
      tokens: message?.tokens,
      finish: message?.finish,
      error: message?.error,
      time: message?.time,
    },
    parts: Array.isArray(parts)
      ? parts.map((p) => ({
          type: p?.type,
          text: p?.type === "text" ? p?.text : undefined,
          synthetic: p?.synthetic,
          toolName: p?.type === "tool" ? p?.tool : undefined,
          callID: p?.type === "tool" ? p?.callID : undefined,
          state: p?.type === "tool" ? p?.state : undefined,
          mime: p?.type === "file" ? p?.mime : undefined,
          filename: p?.type === "file" ? p?.filename : undefined,
          url: p?.type === "file" ? p?.url : undefined,
        }))
      : undefined,
  });
}

export const LlmLoggerPlugin = async ({ directory, client }) => {
  const baseDir = join(directory ?? process.cwd(), ".ai/telamon/logs/llm-logger");

  return {
    "chat.message": async (input, output) => {
      try {
        const sessionID = input?.sessionID;
        const message = output?.message;
        const parts = output?.parts;
        const messageID = input?.messageID ?? message?.id;
        if (!sessionID || !messageID) return;
        const role = message?.role || "unknown";

        writeMessageLog(baseDir, sessionID, messageID, role, message, parts, {
          agent: input?.agent,
          model: input?.model,
          variant: input?.variant,
        });
      } catch (err) {
        process.stderr.write(
          `[llm-logger] Error in chat.message hook: ${err?.message ?? err}\n`,
        );
      }
    },

    event: async ({ event }) => {
      try {
        // Only react to message.updated events for completed assistant messages.
        if (!event || event.type !== "message.updated") return;
        const info = event?.properties?.info;
        if (!info || info.role !== "assistant") return;
        // Wait for completion — `time.completed` is set when the message
        // finishes. Streaming updates have only `time.created`.
        if (!info?.time?.completed) return;

        const sessionID = info.sessionID;
        const messageID = info.id;
        if (!sessionID || !messageID) return;

        // Dedup: `message.updated` may fire more than once even after
        // completion (e.g. metadata refresh). One log file per messageID.
        if (loggedAssistantIds.has(messageID)) return;
        loggedAssistantIds.add(messageID);

        // No client → nothing to fetch. Log just the metadata so we don't
        // silently drop the event.
        if (!client?.session?.message) {
          writeMessageLog(baseDir, sessionID, messageID, "assistant", info, []);
          return;
        }

        let parts = [];
        let fullInfo = info;
        try {
          const result = await client.session.message({
            path: { id: sessionID, messageID },
          });
          const data = result?.data ?? result;
          if (data?.info) fullInfo = data.info;
          if (Array.isArray(data?.parts)) parts = data.parts;
        } catch (fetchErr) {
          process.stderr.write(
            `[llm-logger] Failed to fetch assistant message ${messageID}: ${fetchErr?.message ?? fetchErr}\n`,
          );
          // Fall through and write what we have (metadata only).
        }

        writeMessageLog(baseDir, sessionID, messageID, "assistant", fullInfo, parts);
      } catch (err) {
        process.stderr.write(
          `[llm-logger] Error in event hook: ${err?.message ?? err}\n`,
        );
      }
    },
  };
};

// Test-only: reset shared module state. Attached as a property so the
// module still has exactly ONE named export (the plugin factory).
LlmLoggerPlugin._resetState = () => {
  sessionCreatedAt.clear();
  loggedAssistantIds.clear();
  fileCounter = 0;
};

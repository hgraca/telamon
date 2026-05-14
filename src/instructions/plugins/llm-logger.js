// llm-logger plugin
//
// Logs every LLM message (user request and assistant response) to disk —
// one file per message. Uses only the `chat.message` hook (stable in v1.14.50).
//
// File layout:
//   .ai/telamon/logs/llm-logger/<YYYYMMDDHHMMSS>-<sessionID>/
//     <timestamp>-<seq>-<role>-<messageID>.json
//
// The directory is gitignored via `.ai/telamon` — no risk of leaking prompts
// or responses into version control.
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

export const LlmLoggerPlugin = async ({ directory }) => {
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
        const roleLabel =
          role === "user" ? "request" : role === "assistant" ? "response" : role;
        const ts = Date.now();
        const seq = ++fileCounter;
        const filename = `${ts}-${seq}-${roleLabel}-${messageID}.json`;

        writeLog(baseDir, sessionID, filename, {
          type: "chat.message",
          sessionID,
          messageID,
          agent: input?.agent,
          model: input?.model,
          variant: input?.variant,
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
      } catch (err) {
        process.stderr.write(
          `[llm-logger] Error in chat.message hook: ${err?.message ?? err}\n`,
        );
      }
    },
  };
};

// Test-only: reset shared module state. Attached as a property so the
// module still has exactly ONE named export (the plugin factory).
LlmLoggerPlugin._resetState = () => {
  sessionCreatedAt.clear();
  fileCounter = 0;
};

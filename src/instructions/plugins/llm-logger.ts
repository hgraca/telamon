// llm-logger plugin
//
// Logs every LLM request and response to disk — one file per message.
// Uses only the `chat.message` hook, which fires after all streaming deltas
// have been accumulated into the final message. No streaming-chunk tracking.
//
// File layout:
//   .ai/telamon/logs/llm-logger/<YYYYMMDDHHMMSS>-<sessionID>/
//     <timestamp>-<role>-<messageID>.json
//
// The YYYYMMDDHHMMSS prefix is the wall-clock time when the first message
// for that session was observed (approximates session creation time).
//
// Each file contains the full message info + parts (text, tool calls, etc.)
// plus metadata about the agent, model, and provider that generated it.
//
// The directory is gitignored via `.ai/telamon` — no risk of leaking prompts
// or responses into version control.

import { writeFileSync, mkdirSync, existsSync } from "fs";
import { join } from "path";
import type { Plugin } from "@opencode-ai/plugin";

// Track the first-observed timestamp per session to build sortable folder names.
const sessionCreatedAt = new Map<string, number>();

function formatTimestamp(ts: number): string {
  const d = new Date(ts);
  const pad = (n: number): string => String(n).padStart(2, "0");
  return (
    `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}` +
    `${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
  );
}

export const LlmLoggerPlugin: Plugin = async ({ directory }) => {
  const baseDir = join(directory, ".ai/telamon/logs/llm-logger");

  function sessionDirName(sessionID: string): string {
    const createdAt = sessionCreatedAt.get(sessionID);
    const ts = createdAt ?? Date.now();
    return `${formatTimestamp(ts)}-${sessionID}`;
  }

  function ensureSessionDir(sessionID: string): string {
    const dir = join(baseDir, sessionDirName(sessionID));
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    return dir;
  }

  function writeLog(sessionID: string, filename: string, data: unknown): void {
    const dir = ensureSessionDir(sessionID);
    const path = join(dir, filename);
    try {
      writeFileSync(path, JSON.stringify(data, null, 2), "utf8");
    } catch (err) {
      process.stderr.write(
        `[llm-logger] Failed to write ${path}: ${err?.message ?? err}\n`,
      );
    }
  }

  return {
    "chat.message": async (input, output) => {
      const { sessionID, messageID, agent, model, variant } = input;
      const { message, parts } = output;

      if (!sessionID || !messageID) return;

      // Record session creation time on first observed message.
      if (!sessionCreatedAt.has(sessionID)) {
        sessionCreatedAt.set(sessionID, Date.now());
      }

      const role = message?.role ?? "unknown";
      const ts = Date.now();

      // Sanitize role for filename (user → request, assistant → response)
      const roleLabel = role === "user" ? "request" : role === "assistant" ? "response" : role;

      const filename = `${ts}-${roleLabel}-${messageID}.json`;

      writeLog(sessionID, filename, {
        type: "chat.message",
        sessionID,
        messageID,
        agent,
        model,
        variant,
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
        parts: parts?.map((p) => ({
          type: p.type,
          text: p.type === "text" ? p.text : undefined,
          toolName: p.type === "tool_use" ? p.toolName : undefined,
          toolCallID: p.type === "tool_use" ? p.toolCallID : undefined,
          input: p.type === "tool_use" ? p.input : undefined,
          isError: p.type === "tool_result" ? p.isError : undefined,
          toolResultID: p.type === "tool_result" ? p.toolResultID : undefined,
          content: p.type === "tool_result" ? p.content : undefined,
        })),
      });
    },
  };
};
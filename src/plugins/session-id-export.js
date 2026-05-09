// session-id-export plugin
//
// Exports the current session ID to a per-PID file so child processes
// (shell scripts run via /script, the bash tool, etc.) can read it.
//
// Why a file and not process.env?
//   - process.env mutation only affects the worker process and its future
//     children, which is fine — but a single worker can serve sessions
//     sequentially, so we still need a way to track "which session is
//     active right now". Writing to /tmp/opencode-session-<pid> on every
//     tool execution gives child scripts a deterministic, always-fresh
//     source of truth.
//   - We ALSO set process.env.OPENCODE_SESSION_ID so children that prefer
//     env vars can use it directly. Both are kept in sync.
//
// File path: ${TMPDIR:-/tmp}/opencode-session-${OPENCODE_PID}
// File contents: just the session ID, no newline.
//
// Hooks:
//   - tool.execute.before: refresh on every tool call (covers /script,
//     bash, and every other tool — guaranteed fresh when scripts run).
//   - event (session.idle / session.created): refresh on session lifecycle
//     events as a belt-and-braces measure.
//
// Cleanup: the file is overwritten on every tool call, so stale content
// is never served. We do NOT delete on session end because the same
// worker may immediately start another session.

import { writeFileSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

function sessionFilePath() {
  const pid = process.env.OPENCODE_PID || process.pid;
  return join(process.env.TMPDIR || tmpdir(), `opencode-session-${pid}`);
}

function exportSessionId(sessionId) {
  if (!sessionId || typeof sessionId !== "string") return;
  if (process.env.OPENCODE_SESSION_ID === sessionId) return; // no-op fast path

  process.env.OPENCODE_SESSION_ID = sessionId;

  try {
    writeFileSync(sessionFilePath(), sessionId, "utf8");
  } catch (err) {
    // Non-fatal — log once to stderr.
    process.stderr.write(
      `[session-id-export] Failed to write session file: ${err?.message ?? err}\n`
    );
  }
}

export const SessionIdExportPlugin = async () => {
  return {
    "tool.execute.before": async (input) => {
      exportSessionId(input?.sessionID);
    },

    event: async ({ event }) => {
      if (!event?.type?.startsWith("session.")) return;
      const sessionId =
        event?.properties?.info?.id ||
        event?.properties?.sessionID ||
        event?.properties?.id;
      exportSessionId(sessionId);
    },
  };
};

import { describe, test, expect, beforeAll, beforeEach, afterAll } from "bun:test";
import { mkdirSync, rmSync, readFileSync, existsSync, readdirSync } from "fs";
import { join } from "path";
import { LlmLoggerPlugin } from "../../src/instructions/plugins/llm-logger.js";

let tmpDir: string;
let baseDir: string;

beforeAll(() => {
  tmpDir = join("/tmp", `llm-logger-test-${process.pid}-${Date.now()}`);
  mkdirSync(tmpDir, { recursive: true });
  baseDir = join(tmpDir, ".ai/telamon/logs/llm-logger");
});

beforeEach(() => {
  LlmLoggerPlugin._resetState();
  if (existsSync(baseDir)) {
    rmSync(baseDir, { recursive: true, force: true });
  }
});

afterAll(() => {
  rmSync(tmpDir, { recursive: true, force: true });
});

function sessionFolder(sessionID: string): string | null {
  if (!existsSync(baseDir)) return null;
  const entries = readdirSync(baseDir);
  const match = entries.find((e) => e.endsWith(`-${sessionID}`));
  return match ? join(baseDir, match) : null;
}

function logFiles(sessionID: string): string[] {
  const dir = sessionFolder(sessionID);
  if (!dir) return [];
  return readdirSync(dir).sort();
}

function readLog(sessionID: string, filename: string): unknown {
  const dir = sessionFolder(sessionID);
  if (!dir) throw new Error(`Session folder not found for ${sessionID}`);
  return JSON.parse(readFileSync(join(dir, filename), "utf8"));
}

describe("LlmLoggerPlugin", () => {
  test("writes a file on chat.message for user messages", async () => {
    const hooks = await LlmLoggerPlugin({ directory: tmpDir } as any);
    const handler = hooks["chat.message"]!;

    await handler(
      {
        sessionID: "session-1",
        messageID: "msg-001",
        agent: "telamon/telamon",
        model: { providerID: "github-copilot", modelID: "claude-opus-4.6" },
      },
      {
        message: {
          id: "msg-001",
          sessionID: "session-1",
          role: "user",
          agent: "telamon/telamon",
          model: { providerID: "github-copilot", modelID: "claude-opus-4.6" },
        } as any,
        parts: [
          { type: "text", text: "Hello, can you help me?" },
        ] as any[],
      },
    );

    const files = logFiles("session-1");
    expect(files.length).toBe(1);
    expect(files[0]).toMatch(/^\d+-\d+-request-msg-001\.json$/);

    const log = readLog("session-1", files[0]) as any;
    expect(log.type).toBe("chat.message");
    expect(log.sessionID).toBe("session-1");
    expect(log.messageID).toBe("msg-001");
    expect(log.role).toBe("user");
    expect(log.agent).toBe("telamon/telamon");
    expect(log.model).toEqual({ providerID: "github-copilot", modelID: "claude-opus-4.6" });
    expect(log.parts).toHaveLength(1);
    expect(log.parts[0].type).toBe("text");
    expect(log.parts[0].text).toBe("Hello, can you help me?");

    const folder = sessionFolder("session-1");
    expect(folder).not.toBeNull();
    const folderName = folder!.split("/").pop()!;
    expect(folderName).toMatch(/^\d{14}-session-1$/);
  });

  test("writes a file on chat.message for assistant responses", async () => {
    const hooks = await LlmLoggerPlugin({ directory: tmpDir } as any);
    const handler = hooks["chat.message"]!;

    await handler(
      {
        sessionID: "session-assistant",
        messageID: "msg-002",
        agent: "telamon/telamon",
        model: { providerID: "github-copilot", modelID: "claude-opus-4.6" },
      },
      {
        message: {
          id: "msg-002",
          sessionID: "session-assistant",
          role: "assistant",
          agent: "telamon/telamon",
          modelID: "claude-opus-4.6",
          providerID: "github-copilot",
          cost: 0.002,
          tokens: { input: 100, output: 50, total: 150, reasoning: 0, cache: { read: 0, write: 0 } },
          finish: "stop",
        } as any,
        parts: [
          { type: "text", text: "Sure, I can help!" },
        ] as any[],
      },
    );

    const files = logFiles("session-assistant");
    expect(files.length).toBe(1);

    const log = readLog("session-assistant", files[0]) as any;
    expect(log.role).toBe("assistant");
    expect(log.message.cost).toBe(0.002);
    expect(log.message.tokens.input).toBe(100);
    expect(log.message.tokens.output).toBe(50);
    expect(log.message.finish).toBe("stop");
    expect(log.parts[0].text).toBe("Sure, I can help!");
  });

  test("writes separate session folders with timestamp prefixes", async () => {
    const hooks = await LlmLoggerPlugin({ directory: tmpDir } as any);
    const handler = hooks["chat.message"]!;

    await handler(
      { sessionID: "session-a", messageID: "m1" } as any,
      { message: { role: "user" } as any, parts: [{ type: "text", text: "hi" }] as any[] },
    );
    await handler(
      { sessionID: "session-b", messageID: "m2" } as any,
      { message: { role: "user" } as any, parts: [{ type: "text", text: "hello" }] as any[] },
    );

    expect(logFiles("session-a").length).toBe(1);
    expect(logFiles("session-b").length).toBe(1);

    const folderA = sessionFolder("session-a");
    const folderB = sessionFolder("session-b");
    expect(folderA).not.toBeNull();
    expect(folderB).not.toBeNull();
    expect(folderA!.split("/").pop()!).toMatch(/^\d{14}-session-a$/);
    expect(folderB!.split("/").pop()!).toMatch(/^\d{14}-session-b$/);
  });

  test("handles tool parts (real opencode shape)", async () => {
    const hooks = await LlmLoggerPlugin({ directory: tmpDir } as any);
    const handler = hooks["chat.message"]!;

    await handler(
      { sessionID: "session-3", messageID: "msg-003" } as any,
      {
        message: { role: "assistant" } as any,
        parts: [
          { type: "text", text: "Let me check that." },
          {
            type: "tool",
            tool: "bash",
            callID: "call-1",
            state: { status: "running", input: { command: "ls -la" } },
          },
        ] as any[],
      },
    );

    const files = logFiles("session-3");
    const log = readLog("session-3", files[0]) as any;
    expect(log.parts).toHaveLength(2);
    expect(log.parts[1].type).toBe("tool");
    expect(log.parts[1].toolName).toBe("bash");
    expect(log.parts[1].callID).toBe("call-1");
    expect(log.parts[1].state.input.command).toBe("ls -la");
  });

  test("skips write when sessionID or messageID is missing", async () => {
    const hooks = await LlmLoggerPlugin({ directory: tmpDir } as any);
    const handler = hooks["chat.message"]!;

    await handler(
      { messageID: "m1" } as any,
      { message: { role: "user" } as any, parts: [] as any[] },
    );
    await handler(
      { sessionID: "session-x" } as any,
      { message: { role: "user" } as any, parts: [] as any[] },
    );

    expect(sessionFolder("session-x")).toBeNull();
  });
});

describe("LlmLoggerPlugin event hook (assistant capture)", () => {
  function makeClient(messageData: any, opts: { throws?: boolean } = {}) {
    const calls: any[] = [];
    return {
      calls,
      session: {
        message: async (args: any) => {
          calls.push(args);
          if (opts.throws) throw new Error("fetch failed");
          return { data: messageData };
        },
      },
    };
  }

  function completedAssistantEvent(sessionID: string, messageID: string): any {
    return {
      type: "message.updated",
      properties: {
        info: {
          id: messageID,
          sessionID,
          role: "assistant",
          modelID: "claude-opus-4.6",
          providerID: "github-copilot",
          time: { created: Date.now() - 1000, completed: Date.now() },
        },
      },
    };
  }

  test("captures completed assistant message via client fetch", async () => {
    const client = makeClient({
      info: {
        id: "asst-1",
        sessionID: "session-evt-1",
        role: "assistant",
        modelID: "claude-opus-4.6",
        providerID: "github-copilot",
        cost: 0.005,
        tokens: { input: 200, output: 80, total: 280, reasoning: 0, cache: { read: 0, write: 0 } },
        finish: "stop",
        time: { created: 1000, completed: 2000 },
      },
      parts: [
        { type: "text", text: "Here is the answer." },
        { type: "tool", tool: "read", callID: "c-1", state: { status: "completed", input: { path: "/x" }, output: "ok" } },
      ],
    });

    const hooks = await LlmLoggerPlugin({ directory: tmpDir, client } as any);
    const handler = hooks.event!;

    await handler({ event: completedAssistantEvent("session-evt-1", "asst-1") } as any);

    expect(client.calls).toHaveLength(1);
    expect(client.calls[0]).toEqual({ path: { id: "session-evt-1", messageID: "asst-1" } });

    const files = logFiles("session-evt-1");
    expect(files.length).toBe(1);
    expect(files[0]).toMatch(/^\d+-\d+-response-asst-1\.json$/);

    const log = readLog("session-evt-1", files[0]) as any;
    expect(log.role).toBe("assistant");
    expect(log.message.cost).toBe(0.005);
    expect(log.message.tokens.output).toBe(80);
    expect(log.message.finish).toBe("stop");
    expect(log.parts).toHaveLength(2);
    expect(log.parts[0].text).toBe("Here is the answer.");
    expect(log.parts[1].toolName).toBe("read");
    expect(log.parts[1].callID).toBe("c-1");
  });

  test("dedupes repeated message.updated events for same messageID", async () => {
    const client = makeClient({
      info: { id: "asst-2", sessionID: "session-evt-2", role: "assistant", time: { completed: 1 } },
      parts: [{ type: "text", text: "once" }],
    });

    const hooks = await LlmLoggerPlugin({ directory: tmpDir, client } as any);
    const handler = hooks.event!;
    const evt = completedAssistantEvent("session-evt-2", "asst-2");

    await handler({ event: evt } as any);
    await handler({ event: evt } as any);
    await handler({ event: evt } as any);

    expect(client.calls.length).toBe(1);
    expect(logFiles("session-evt-2").length).toBe(1);
  });

  test("ignores non-assistant message.updated events", async () => {
    const client = makeClient({ info: {}, parts: [] });
    const hooks = await LlmLoggerPlugin({ directory: tmpDir, client } as any);
    const handler = hooks.event!;

    await handler({
      event: {
        type: "message.updated",
        properties: {
          info: { id: "u-1", sessionID: "session-evt-3", role: "user", time: { completed: 1 } },
        },
      },
    } as any);

    expect(client.calls.length).toBe(0);
    expect(sessionFolder("session-evt-3")).toBeNull();
  });

  test("ignores assistant messages that have not completed yet", async () => {
    const client = makeClient({ info: {}, parts: [] });
    const hooks = await LlmLoggerPlugin({ directory: tmpDir, client } as any);
    const handler = hooks.event!;

    await handler({
      event: {
        type: "message.updated",
        properties: {
          info: {
            id: "asst-3",
            sessionID: "session-evt-4",
            role: "assistant",
            time: { created: Date.now() }, // no completed
          },
        },
      },
    } as any);

    expect(client.calls.length).toBe(0);
    expect(sessionFolder("session-evt-4")).toBeNull();
  });

  test("ignores event types other than message.updated", async () => {
    const client = makeClient({ info: {}, parts: [] });
    const hooks = await LlmLoggerPlugin({ directory: tmpDir, client } as any);
    const handler = hooks.event!;

    await handler({ event: { type: "session.idle", properties: {} } } as any);
    await handler({ event: { type: "message.part.updated", properties: {} } } as any);

    expect(client.calls.length).toBe(0);
  });

  test("falls back to metadata-only log when client fetch throws", async () => {
    const client = makeClient(null, { throws: true });
    const hooks = await LlmLoggerPlugin({ directory: tmpDir, client } as any);
    const handler = hooks.event!;

    await handler({ event: completedAssistantEvent("session-evt-5", "asst-5") } as any);

    const files = logFiles("session-evt-5");
    expect(files.length).toBe(1);
    const log = readLog("session-evt-5", files[0]) as any;
    expect(log.role).toBe("assistant");
    expect(log.messageID).toBe("asst-5");
    expect(log.parts).toEqual([]);
  });

  test("writes metadata-only log when no client is provided", async () => {
    const hooks = await LlmLoggerPlugin({ directory: tmpDir } as any);
    const handler = hooks.event!;

    await handler({ event: completedAssistantEvent("session-evt-6", "asst-6") } as any);

    const files = logFiles("session-evt-6");
    expect(files.length).toBe(1);
    const log = readLog("session-evt-6", files[0]) as any;
    expect(log.role).toBe("assistant");
    expect(log.parts).toEqual([]);
  });
});
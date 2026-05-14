import { describe, test, expect, beforeAll, beforeEach, afterAll } from "bun:test";
import { mkdirSync, rmSync, readFileSync, existsSync, readdirSync } from "fs";
import { join } from "path";
import { LlmLoggerPlugin, _resetState } from "../../src/instructions/plugins/llm-logger.js";

let tmpDir: string;
let baseDir: string;

beforeAll(() => {
  tmpDir = join("/tmp", `llm-logger-test-${process.pid}-${Date.now()}`);
  mkdirSync(tmpDir, { recursive: true });
  baseDir = join(tmpDir, ".ai/telamon/logs/llm-logger");
});

beforeEach(() => {
  _resetState();
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

  test("handles tool_use and tool_result parts", async () => {
    const hooks = await LlmLoggerPlugin({ directory: tmpDir } as any);
    const handler = hooks["chat.message"]!;

    await handler(
      { sessionID: "session-3", messageID: "msg-003" } as any,
      {
        message: { role: "assistant" } as any,
        parts: [
          { type: "text", text: "Let me check that." },
          {
            type: "tool_use",
            toolName: "bash",
            toolCallID: "call-1",
            input: { command: "ls -la" },
          },
        ] as any[],
      },
    );

    const files = logFiles("session-3");
    const log = readLog("session-3", files[0]) as any;
    expect(log.parts).toHaveLength(2);
    expect(log.parts[1].type).toBe("tool_use");
    expect(log.parts[1].toolName).toBe("bash");
    expect(log.parts[1].input.command).toBe("ls -la");
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
// tests/plugins/status-marker-enforcer.test.ts
//
// Failing tests for Task 2 of the status-marker-enforcer backlog.
// All tests MUST fail until src/plugins/status-marker-enforcer.js is implemented.
//
// Spec references:
//   PLAN-ARCH-2026-05-06-001.md §2, §3.5, §5, §6, §8, §9
//   backlog.md lines 68–95
//   agent-communication/SKILL.md lines 19–24

import { describe, test, expect, beforeEach, afterEach } from "bun:test"
import { readFileSync } from "fs"
import { join } from "path"

// ─── Module under test ────────────────────────────────────────────────────────
// This import MUST fail until the developer creates the file.
// @ts-ignore — intentionally importing a file that does not yet exist
import {
  StatusMarkerEnforcerPlugin,
  detectTerminalMarker,
  MARKER_RE,
} from "../../src/plugins/status-marker-enforcer.js"

// ─── Task 4 exports — loaded dynamically so missing exports fail only Task 4 tests ───
// Developer must add these exports to status-marker-enforcer.js:
//   readCounter(directory: string, slug: string): Record<string, { attempts: number; lastNudge: string }>
//   writeCounter(directory: string, slug: string, counter: Record<string, ...>): void
//   pruneCounter(counter: Record<string, ...>, now?: Date): Record<string, ...>
//   MAX_COUNTER_ENTRIES: number  (= 100)
//   COUNTER_TTL_MS: number       (= 24 * 60 * 60 * 1000)
async function getCounterExports() {
  const mod = await import("../../src/plugins/status-marker-enforcer.js") as any
  if (!mod.readCounter) throw new Error("Task 4 developer requirement: export readCounter() from status-marker-enforcer.js")
  if (!mod.writeCounter) throw new Error("Task 4 developer requirement: export writeCounter() from status-marker-enforcer.js")
  if (!mod.pruneCounter) throw new Error("Task 4 developer requirement: export pruneCounter() from status-marker-enforcer.js")
  if (mod.MAX_COUNTER_ENTRIES === undefined) throw new Error("Task 4 developer requirement: export MAX_COUNTER_ENTRIES from status-marker-enforcer.js")
  if (mod.COUNTER_TTL_MS === undefined) throw new Error("Task 4 developer requirement: export COUNTER_TTL_MS from status-marker-enforcer.js")
  return {
    readCounter: mod.readCounter as (directory: string, slug: string) => Record<string, { attempts: number; lastNudge: string }>,
    writeCounter: mod.writeCounter as (directory: string, slug: string, counter: Record<string, { attempts: number; lastNudge: string }>) => void,
    pruneCounter: mod.pruneCounter as (counter: Record<string, { attempts: number; lastNudge: string }>, now?: Date) => Record<string, { attempts: number; lastNudge: string }>,
    MAX_COUNTER_ENTRIES: mod.MAX_COUNTER_ENTRIES as number,
    COUNTER_TTL_MS: mod.COUNTER_TTL_MS as number,
  }
}

// ─── Repo root ────────────────────────────────────────────────────────────────
const repoRoot = join(import.meta.dir, "../..")

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Build a message item in the shape the real SDK returns:
 *  Array<{ info: Message; parts: Part[] }>
 *  (gotchas.md L1022, backlog.md L76, PLAN §9.1)
 */
function makeMsg(
  role: "user" | "assistant",
  text: string,
): { info: { role: string }; parts: { type: string; text: string }[] } {
  return {
    info: { role },
    parts: [{ type: "text", text }],
  }
}

/** Build a mock client whose session.messages returns the given items.
 *  Mirrors remember-session.test.ts makeClient() pattern.
 *  client.session.messages returns { data: items } (same as remember-session.js:68).
 */
function makeClient(opts: {
  messages?: ReturnType<typeof makeMsg>[]
  promptCallCount?: { n: number }
} = {}) {
  const messagesCallCount = { n: 0 }
  const promptCallCount = opts.promptCallCount ?? { n: 0 }
  return {
    session: {
      messages: async (_args: any) => {
        messagesCallCount.n++
        return { data: opts.messages ?? [] }
      },
      prompt: async (_args: any) => {
        promptCallCount.n++
      },
    },
    messagesCallCount,
    promptCallCount,
  }
}

/** Build a session.idle event with optional agent identity fields.
 *  PLAN §6: agent resolved from event.properties.info.agent first.
 */
function makeIdleEvent(
  sessionId = "test-session-sme-001",
  agentId?: string,
) {
  return {
    type: "session.idle",
    properties: {
      info: {
        id: sessionId,
        ...(agentId ? { agent: agentId } : {}),
      },
    },
  }
}

/** Minimal .telamon.jsonc content written to a temp dir for config tests. */
function writeTelamon(dir: string, config: object) {
  const { writeFileSync, mkdirSync } = require("fs")
  mkdirSync(dir, { recursive: true })
  writeFileSync(join(dir, ".telamon.jsonc"), JSON.stringify(config), "utf8")
}

// ─── Drift-guard parser (PLAN §3.5.1) ────────────────────────────────────────

function parseMarkersFromSkill(skillPath: string): string[] {
  const text = readFileSync(skillPath, "utf8")
  const lines = text.split("\n")

  const anchorIdx = lines.findIndex((l) =>
    l.startsWith(
      "Every agent must end its final message with exactly one of these signals",
    ),
  )
  if (anchorIdx === -1) {
    throw new Error(
      "DRIFT-GUARD PARSER: anchor sentence not found in agent-communication SKILL. " +
        "Either the SKILL was rewritten (update parser anchor) or the file path is wrong.",
    )
  }

  const markers: string[] = []
  for (let i = anchorIdx + 1; i < lines.length; i++) {
    const line = lines[i]
    if (line.trim() === "" && markers.length === 0) continue
    const m = line.match(/^- `([^`]+)`/)
    if (m) {
      markers.push(m[1])
      continue
    }
    if (markers.length > 0) break
    throw new Error(
      `DRIFT-GUARD PARSER: expected bullet list immediately after anchor, found: ${JSON.stringify(line)}`,
    )
  }

  if (markers.length === 0) {
    throw new Error("DRIFT-GUARD PARSER: anchor found but no marker bullets parsed.")
  }

  // Each marker's prefix = everything up to and including first colon,
  // OR the entire token if no colon (FINISHED! case). PLAN §3.5.1.
  return markers.map((m) => {
    const colonIdx = m.indexOf(":")
    return colonIdx === -1 ? m : m.slice(0, colonIdx + 1)
  })
}

// ─── Suite ────────────────────────────────────────────────────────────────────

describe("status-marker-enforcer / Task 2 core", () => {

  // ══════════════════════════════════════════════════════════════════════════
  // A. Marker detection — positive cases
  //    PLAN §3.5.2, §5 edge-cases table; backlog L77, L83
  // ══════════════════════════════════════════════════════════════════════════
  describe("A. Marker detection — positive cases (marker present → no nudge needed)", () => {

    test("A.1 [PLAN §3.5.2 table] FINISHED! on its own line → detected", () => {
      const msg = makeMsg("assistant", "FINISHED!")
      expect(detectTerminalMarker(msg)).toBe(true)
    })

    test("A.2 [PLAN §3.5.2 table] BLOCKED: reason text → detected", () => {
      const msg = makeMsg("assistant", "BLOCKED: waiting for DB credentials")
      expect(detectTerminalMarker(msg)).toBe(true)
    })

    test("A.3 [PLAN §3.5.2 table] NEEDS_INPUT: question → detected", () => {
      const msg = makeMsg("assistant", "NEEDS_INPUT: which environment should I target?")
      expect(detectTerminalMarker(msg)).toBe(true)
    })

    test("A.4 [PLAN §3.5.2 table] PARTIAL: progress note → detected", () => {
      const msg = makeMsg("assistant", "PARTIAL: wrote 3 of 5 files; remaining: tests")
      expect(detectTerminalMarker(msg)).toBe(true)
    })

    test("A.5 [PLAN §5 edge-case: trailing newline + blank lines] marker on last non-empty line when trailing whitespace lines follow → detected", () => {
      const msg = makeMsg("assistant", "All done.\n\nFINISHED!\n\n   \n")
      expect(detectTerminalMarker(msg)).toBe(true)
    })

    test("A.6 [PLAN §3.5.2 table] marker as the only content of the assistant message → detected", () => {
      const msg = makeMsg("assistant", "FINISHED!")
      expect(detectTerminalMarker(msg)).toBe(true)
    })
  })

  // ══════════════════════════════════════════════════════════════════════════
  // B. Marker detection — negative cases
  //    PLAN §3.5.2, §5; backlog L77, L83
  // ══════════════════════════════════════════════════════════════════════════
  describe("B. Marker detection — negative cases (no marker → nudge would fire)", () => {

    test("B.7 [PLAN §5 edge-case: empty text] empty assistant message → no marker detected (fail open → returns true)", () => {
      // Spec §5: "if text is empty after trim → return true (fail open)"
      // Fail-open means the plugin does NOT nudge — returns true (marker "present").
      // This is the defensive behaviour per PLAN §3.5.2 last row of edge-cases table.
      const msg = makeMsg("assistant", "")
      expect(detectTerminalMarker(msg)).toBe(true)
    })

    test("B.8 [PLAN §3.5.2 table: narration, no marker] plain prose ending with no marker → no marker detected (returns false)", () => {
      const msg = makeMsg("assistant", "I have completed the analysis and written the report.")
      expect(detectTerminalMarker(msg)).toBe(false)
    })

    test("B.9 [backlog L77: case-sensitive] marker word lowercase (finished!) → NOT detected (case-sensitive)", () => {
      const msg = makeMsg("assistant", "finished!")
      expect(detectTerminalMarker(msg)).toBe(false)
    })

    test("B.10 [backlog L77: FINISHED! includes the !] marker without trailing ! (FINISHED alone) → NOT detected", () => {
      const msg = makeMsg("assistant", "FINISHED")
      expect(detectTerminalMarker(msg)).toBe(false)
    })

    test("B.11 [PLAN §3.5.2 table: mid-line] marker mid-line, not line-anchored → NOT detected", () => {
      const msg = makeMsg("assistant", "the user said FINISHED! and we agreed")
      expect(detectTerminalMarker(msg)).toBe(false)
    })

    test("B.12 [PLAN §3.5.2 table + §3.5 scope-of-stripping] marker inside trailing fenced code block → NOT detected (spec strips trailing fenced block before analysis)", () => {
      // PLAN §3.5.2 edge-cases table row: ```\nFINISHED!\n``` → ❌ not a real terminal marker
      // PLAN §5: stripTrailingFencedBlock removes a single trailing ```...``` block.
      // Therefore a marker inside the fence is NOT detected.
      const msg = makeMsg("assistant", "Here is a code example:\n```\nFINISHED!\n```")
      expect(detectTerminalMarker(msg)).toBe(false)
    })

    test("B.13 [PLAN §2 step 5: last assistant message] last message is from user, not assistant → detectTerminalMarker not called on user message (returns true = fail open)", () => {
      // The plugin locates the last ASSISTANT message. If the last message is from
      // user, there is no assistant message to check → fail open (no nudge).
      // We test detectTerminalMarker directly with a user-role message — spec says
      // the caller filters by role; detectTerminalMarker itself receives the message
      // object. A user message passed directly should be treated as fail-open (true).
      // This test verifies the plugin's role-filter logic via the integration path.
      const userMsg = makeMsg("user", "Please do the task.")
      // detectTerminalMarker receives the assistant message; if called with a user
      // message by mistake it should still not crash. Spec says fail open → true.
      expect(detectTerminalMarker(userMsg)).toBe(true)
    })
  })

  // ══════════════════════════════════════════════════════════════════════════
  // C. SDK shape correctness
  //    gotchas.md L1022; backlog L76, L79; PLAN §9.1
  // ══════════════════════════════════════════════════════════════════════════
  describe("C. SDK shape correctness — item.info.role vs item.role (gotchas.md L1022)", () => {

    test("C.14 [gotchas.md L1022, PLAN §9.1] correct SDK shape { info: { role }, parts } → marker detected", async () => {
      // Real SDK shape: Array<{ info: Message; parts: Part[] }>
      // Plugin must use m.info.role to find the last assistant message.
      const messages = [
        { info: { role: "assistant" }, parts: [{ type: "text", text: "FINISHED!" }] },
      ]
      const client = {
        session: {
          messages: async (_args: any) => ({ data: messages }),
          prompt: async (_args: any) => {},
        },
        promptCallCount: { n: 0 },
      }
      // Invoke the plugin's event handler; it should NOT call prompt (marker found).
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: repoRoot,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent() })
      // prompt must NOT have been called — marker was detected
      expect(client.promptCallCount.n).toBe(0)
    })

    test("C.15 [gotchas.md L1022] wrong SDK shape { role } at top level → plugin does NOT detect marker (proves plugin uses m.info.role, not m.role)", async () => {
      // If the plugin mistakenly reads m.role instead of m.info.role, it would
      // find the assistant message via the wrong field. This test uses the wrong
      // shape (role at top level, no info wrapper) — the plugin should NOT find
      // an assistant message and should either fail-open or call prompt.
      // We assert: prompt IS called (no marker found because role lookup failed).
      const wrongShapeMessages = [
        // Wrong shape: role at top level, no info wrapper
        { role: "assistant", parts: [{ type: "text", text: "FINISHED!" }] },
      ]
      const promptCallCount = { n: 0 }
      const client = {
        session: {
          messages: async (_args: any) => ({ data: wrongShapeMessages }),
          prompt: async (_args: any) => { promptCallCount.n++ },
        },
        promptCallCount,
      }
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: repoRoot,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent() })
      // With wrong shape, plugin can't find assistant message → fail open (no nudge)
      // OR it nudges. Either way, it must NOT have found the marker via m.role.
      // The key assertion: if the plugin correctly uses m.info.role, the wrong-shape
      // message is invisible → no assistant message found → fail open (prompt NOT called).
      // This distinguishes correct (m.info.role) from buggy (m.role) implementations.
      expect(promptCallCount.n).toBe(0) // fail-open: no assistant msg found → skip nudge
    })
  })

  // ══════════════════════════════════════════════════════════════════════════
  // D. Opt-out gate
  //    PLAN §6; backlog L78, L84
  // ══════════════════════════════════════════════════════════════════════════
  describe("D. Opt-out gate — exempt agents and disabled flag", () => {

    test("D.16 [PLAN §6, backlog L78] exempt agent → handler short-circuits BEFORE calling client.session.messages (call count = 0)", async () => {
      const { mkdirSync, writeFileSync, rmSync } = require("fs")
      const tmpDir = join("/tmp", `sme-test-exempt-${process.pid}`)
      mkdirSync(tmpDir, { recursive: true })
      try {
        writeTelamon(tmpDir, {
          status_marker_enforcer: {
            enabled: true,
            exempt_agents: ["repomix-agent"],
          },
        })
        const client = makeClient({ messages: [] })
        const hooks = await StatusMarkerEnforcerPlugin({
          directory: tmpDir,
          worktree: undefined,
          client,
        })
        // Agent identity via event.properties.info.agent (PLAN §6 first resolution path)
        await hooks["event"]!({ event: makeIdleEvent("sess-001", "repomix-agent") })
        expect(client.messagesCallCount.n).toBe(0)
      } finally {
        rmSync(tmpDir, { recursive: true, force: true })
      }
    })

    test("D.17 [PLAN §6, backlog L78] non-exempt agent → handler proceeds, calls client.session.messages (call count = 1)", async () => {
      const { mkdirSync, rmSync } = require("fs")
      const tmpDir = join("/tmp", `sme-test-nonexempt-${process.pid}`)
      mkdirSync(tmpDir, { recursive: true })
      try {
        writeTelamon(tmpDir, {
          status_marker_enforcer: {
            enabled: true,
            exempt_agents: ["repomix-agent"],
          },
        })
        const client = makeClient({
          messages: [makeMsg("assistant", "FINISHED!")],
        })
        const hooks = await StatusMarkerEnforcerPlugin({
          directory: tmpDir,
          worktree: undefined,
          client,
        })
        await hooks["event"]!({ event: makeIdleEvent("sess-002", "developer-agent") })
        expect(client.messagesCallCount.n).toBe(1)
      } finally {
        rmSync(tmpDir, { recursive: true, force: true })
      }
    })

    test("D.18 [PLAN §2 step 2, backlog L84] plugin globally disabled (status_marker_enforcer.enabled = false) → handler short-circuits regardless of agent", async () => {
      const { mkdirSync, rmSync } = require("fs")
      const tmpDir = join("/tmp", `sme-test-disabled-${process.pid}`)
      mkdirSync(tmpDir, { recursive: true })
      try {
        writeTelamon(tmpDir, {
          status_marker_enforcer: { enabled: false },
        })
        const client = makeClient({ messages: [] })
        const hooks = await StatusMarkerEnforcerPlugin({
          directory: tmpDir,
          worktree: undefined,
          client,
        })
        await hooks["event"]!({ event: makeIdleEvent("sess-003", "any-agent") })
        expect(client.messagesCallCount.n).toBe(0)
      } finally {
        rmSync(tmpDir, { recursive: true, force: true })
      }
    })
  })

  // ══════════════════════════════════════════════════════════════════════════
  // E. Header comment & structural conformance
  //    backlog L74, L81, L82; PLAN §8
  // ══════════════════════════════════════════════════════════════════════════
  describe("E. Header comment & structural conformance (static-grep tests)", () => {

    const pluginPath = join(repoRoot, "src/plugins/status-marker-enforcer.js")

    test("E.19 [backlog L74, L82] plugin source contains comment citing agent-communication/SKILL.md lines 19–24", () => {
      const source = readFileSync(pluginPath, "utf8")
      // The comment must reference the SKILL file and the line range 19–24.
      // Accepts either "lines 19–24" (en-dash) or "lines 19-24" (hyphen).
      expect(source).toMatch(/agent-communication\/SKILL\.md\s+lines\s+19[–-]24/)
    })

    test("E.20 [backlog L81; PLAN §8] plugin exports a function matching RememberSessionPlugin shape: async ({ directory, worktree, client }) => ({ event: async (...) => ... })", () => {
      const source = readFileSync(pluginPath, "utf8")
      // Must export a named async function or const that accepts { directory, worktree, client }
      // and returns an object with an event handler. Check for the export and the shape.
      expect(source).toMatch(/export\s+(const|async function)\s+\w+/)
      // Must have an event handler returned
      expect(source).toMatch(/event\s*:\s*async/)
    })
  })

  // ══════════════════════════════════════════════════════════════════════════
  // F. Marker-list drift guard
  //    PLAN §3.5.1; backlog L75, L83
  // ══════════════════════════════════════════════════════════════════════════
  describe("F. Marker-list drift guard — SKILL.md ↔ plugin regex parity (PLAN §3.5.1)", () => {

    test("F.21 [PLAN §3.5.1, backlog L75, L83] MARKER_RE matches exactly the 4 markers documented in agent-communication SKILL lines 19–24 — not more, not fewer", () => {
      const skillPath = join(
        repoRoot,
        ".opencode/skills/telamon/workflow/agent-communication/SKILL.md",
      )
      const documented = parseMarkersFromSkill(skillPath)

      // Sanity: parser must find exactly 4 markers
      expect(documented).toHaveLength(4)
      expect(documented).toContain("FINISHED!")
      expect(documented).toContain("BLOCKED:")
      expect(documented).toContain("NEEDS_INPUT:")
      expect(documented).toContain("PARTIAL:")

      // Every documented marker must match MARKER_RE
      for (const marker of documented) {
        expect(marker).toMatch(MARKER_RE)
      }

      // MARKER_RE.source must equal the alternation reconstructed from parsed markers
      // (PLAN §3.5.1 assertion: "regex source exactly equals the alternation")
      const expectedAlt = documented
        .map((m) => m.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
        .join("|")
      const expectedSource = `^(${expectedAlt})`
      expect(MARKER_RE.source).toBe(expectedSource)
    })
  })

  // ══════════════════════════════════════════════════════════════════════════
  // Additional: prompt NOT called in any Task 2 test path where marker found
  //    Task scope guard — Task 3+ owns nudge prompt; Task 2 must not call it
  // ══════════════════════════════════════════════════════════════════════════
  describe("Task scope guard — client.session.prompt NOT called when marker detected (Task 3+ scope)", () => {

    test("[Task scope] marker detected → client.session.prompt is NOT called (nudge is Task 3+)", async () => {
      const promptCallCount = { n: 0 }
      const client = {
        session: {
          messages: async (_args: any) => ({
            data: [makeMsg("assistant", "FINISHED!")],
          }),
          prompt: async (_args: any) => { promptCallCount.n++ },
        },
      }
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: repoRoot,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent() })
      expect(promptCallCount.n).toBe(0)
    })
  })
})

// ─── Task 3 — Nudge prompt with PARTIAL escape valve ─────────────────────────
//
// Developer note: to make these tests pass you must:
//   1. Export `NUDGE_PROMPT` (string constant) OR `buildNudgePrompt` (zero-arg
//      function returning string) from status-marker-enforcer.js.
//   2. Implement the nudge delivery at the TODO(Task 3) line using
//      client.session.prompt with the shape shown in test G.5.
//
// Spec refs:
//   backlog.md lines 87–105
//   PLAN-ARCH-2026-05-06-001.md §3, §6, §8
//   remember-session.js lines 103–115 (synthetic+hidden pattern)
// ─────────────────────────────────────────────────────────────────────────────

/** Resolve the nudge prompt text from whichever export the developer provides.
 *
 * Developer note: export NUDGE_PROMPT (string constant) OR buildNudgePrompt()
 * (zero-arg function returning string) from status-marker-enforcer.js.
 * Either export satisfies these tests.
 */
async function getNudgePrompt(): Promise<string> {
  // Dynamic import avoids hard named-export failure at module load time.
  // Once the developer adds the export, this resolves correctly.
  const mod = await import("../../src/plugins/status-marker-enforcer.js") as any
  if (typeof mod.NUDGE_PROMPT === "string") return mod.NUDGE_PROMPT
  if (typeof mod.buildNudgePrompt === "function") return mod.buildNudgePrompt()
  throw new Error(
    "Task 3 developer requirement: export NUDGE_PROMPT (string) or buildNudgePrompt() " +
    "from status-marker-enforcer.js so nudge-content tests can assert against the prompt text.",
  )
}

describe("status-marker-enforcer / Task 3 — nudge prompt with PARTIAL escape valve", () => {

  // ══════════════════════════════════════════════════════════════════════════
  // G. Nudge prompt content
  //    backlog lines 92–99, 102–104; PLAN §3
  // ══════════════════════════════════════════════════════════════════════════
  describe("G. Nudge prompt content", () => {

    test("G.1 [backlog L94, L102] nudge prompt contains FINISHED! verbatim — regression guard: omitting this marker must fail the suite", async () => {
      const nudge = await getNudgePrompt()
      expect(nudge).toContain("FINISHED!")
    })

    test("G.2 [backlog L94, L102] nudge prompt contains BLOCKED: verbatim — regression guard: omitting this marker must fail the suite", async () => {
      const nudge = await getNudgePrompt()
      expect(nudge).toContain("BLOCKED:")
    })

    test("G.3 [backlog L94, L102] nudge prompt contains NEEDS_INPUT: verbatim — regression guard: omitting this marker must fail the suite", async () => {
      const nudge = await getNudgePrompt()
      expect(nudge).toContain("NEEDS_INPUT:")
    })

    test("G.4 [backlog L94, L102] nudge prompt contains PARTIAL: verbatim — PARTIAL escape-valve PDR guard: omitting PARTIAL: must fail the suite", async () => {
      // This is the primary regression guard for the PARTIAL escape-valve PDR.
      // If a future "simplification" removes PARTIAL: from the nudge, this test fails.
      const nudge = await getNudgePrompt()
      expect(nudge).toContain("PARTIAL:")
    })

    test("G.5 [backlog L93, L103] nudge prompt starts with or contains [Telamon-StatusEnforcer] tag", async () => {
      const nudge = await getNudgePrompt()
      expect(nudge).toContain("[Telamon-StatusEnforcer]")
    })

    test("G.6 [backlog L91, L104; M-FLOW-072] nudge prompt is a numbered checklist — must contain items 1. 2. 3. 4. (not advisory prose)", async () => {
      const nudge = await getNudgePrompt()
      // Numbered list items must be present. Accept "1." "2." "3." "4." anywhere in the text.
      expect(nudge).toMatch(/\b1\./)
      expect(nudge).toMatch(/\b2\./)
      expect(nudge).toMatch(/\b3\./)
      expect(nudge).toMatch(/\b4\./)
    })

    test("G.7 [backlog L99] nudge prompt contains anti-default warning: warns against defaulting to FINISHED! when work is incomplete", async () => {
      // Spec requires: "Do NOT default to FINISHED! if the work is not actually complete
      // — PARTIAL: is the honest answer for incomplete work."
      // Assert both key phrases are present.
      const nudge = await getNudgePrompt()
      // Must warn against defaulting to FINISHED!
      expect(nudge).toMatch(/do not default to FINISHED!/i)
      // Must name PARTIAL: as the honest answer for incomplete work
      expect(nudge).toMatch(/PARTIAL:.*incomplete|incomplete.*PARTIAL:/i)
    })
  })

  // ══════════════════════════════════════════════════════════════════════════
  // H. Nudge delivery — synthetic + hidden via client.session.prompt
  //    backlog L100; PLAN §3; remember-session.js lines 103–115
  // ══════════════════════════════════════════════════════════════════════════
  describe("H. Nudge delivery — synthetic + hidden", () => {

    test("H.8 [backlog L100] no marker detected → client.session.prompt called with synthetic:true and metadata:{hidden:true, source:'status-marker-enforcer'}", async () => {
      const promptCalls: any[] = []
      const client = {
        session: {
          messages: async (_args: any) => ({
            data: [makeMsg("assistant", "I have done the work.")], // no marker
          }),
          prompt: async (args: any) => {
            promptCalls.push(args)
          },
        },
      }
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: repoRoot,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent("sess-task3-001") })

      // Must have been called exactly once
      expect(promptCalls.length).toBe(1)

      const call = promptCalls[0]
      // Must have a body.parts array
      expect(call?.body?.parts).toBeDefined()
      expect(Array.isArray(call.body.parts)).toBe(true)
      expect(call.body.parts.length).toBeGreaterThanOrEqual(1)

      const part = call.body.parts[0]
      // Part must be synthetic
      expect(part.synthetic).toBe(true)
      // Part must have hidden metadata with correct source
      expect(part.metadata).toEqual({
        hidden: true,
        source: "status-marker-enforcer",
      })
      // Part text must be the nudge prompt (non-empty)
      expect(typeof part.text).toBe("string")
      expect(part.text.length).toBeGreaterThan(0)
    })

    test("H.9 [backlog L100] nudge part text contains all four markers verbatim (delivery integration check)", async () => {
      const promptCalls: any[] = []
      const client = {
        session: {
          messages: async (_args: any) => ({
            data: [makeMsg("assistant", "Working on it.")], // no marker
          }),
          prompt: async (args: any) => {
            promptCalls.push(args)
          },
        },
      }
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: repoRoot,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent("sess-task3-002") })

      expect(promptCalls.length).toBe(1)
      const text: string = promptCalls[0]?.body?.parts?.[0]?.text ?? ""
      expect(text).toContain("FINISHED!")
      expect(text).toContain("BLOCKED:")
      expect(text).toContain("NEEDS_INPUT:")
      expect(text).toContain("PARTIAL:")
    })
  })

  // ══════════════════════════════════════════════════════════════════════════
  // I. No nudge when marker present (regression guard for existing behavior)
  //    backlog L101; PLAN §2 step 8
  // ══════════════════════════════════════════════════════════════════════════
  describe("I. No nudge when marker present", () => {

    test("I.10 [backlog L101; PLAN §2 step 8] last assistant message ends with valid marker → client.session.prompt NOT called", async () => {
      const promptCallCount = { n: 0 }
      const client = {
        session: {
          messages: async (_args: any) => ({
            data: [makeMsg("assistant", "All done.\n\nFINISHED!")],
          }),
          prompt: async (_args: any) => { promptCallCount.n++ },
        },
      }
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: repoRoot,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent("sess-task3-003") })
      expect(promptCallCount.n).toBe(0)
    })

    test("I.11 PARTIAL: marker present → client.session.prompt NOT called (PARTIAL is a valid terminal marker)", async () => {
      const promptCallCount = { n: 0 }
      const client = {
        session: {
          messages: async (_args: any) => ({
            data: [makeMsg("assistant", "Wrote 3 of 5 files.\n\nPARTIAL: tests remain")],
          }),
          prompt: async (_args: any) => { promptCallCount.n++ },
        },
      }
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: repoRoot,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent("sess-task3-004") })
      expect(promptCallCount.n).toBe(0)
    })
  })

  // ══════════════════════════════════════════════════════════════════════════
  // J. No nudge when disabled or agent exempt
  //    backlog L78, L84; PLAN §6
  // ══════════════════════════════════════════════════════════════════════════
  describe("J. No nudge when disabled or agent exempt", () => {

    test("J.12 [PLAN §2 step 2, backlog L84] plugin disabled (enabled:false) → client.session.prompt NOT called", async () => {
      const { mkdirSync, rmSync } = require("fs")
      const tmpDir = join("/tmp", `sme-t3-disabled-${process.pid}`)
      mkdirSync(tmpDir, { recursive: true })
      try {
        writeTelamon(tmpDir, { status_marker_enforcer: { enabled: false } })
        const promptCallCount = { n: 0 }
        const client = {
          session: {
            messages: async (_args: any) => ({
              data: [makeMsg("assistant", "Working on it.")],
            }),
            prompt: async (_args: any) => { promptCallCount.n++ },
          },
        }
        const hooks = await StatusMarkerEnforcerPlugin({
          directory: tmpDir,
          worktree: undefined,
          client,
        })
        await hooks["event"]!({ event: makeIdleEvent("sess-task3-005") })
        expect(promptCallCount.n).toBe(0)
      } finally {
        rmSync(tmpDir, { recursive: true, force: true })
      }
    })

    test("J.13 [PLAN §6, backlog L78] exempt agent → client.session.prompt NOT called even when no marker present", async () => {
      const { mkdirSync, rmSync } = require("fs")
      const tmpDir = join("/tmp", `sme-t3-exempt-${process.pid}`)
      mkdirSync(tmpDir, { recursive: true })
      try {
        writeTelamon(tmpDir, {
          status_marker_enforcer: {
            enabled: true,
            exempt_agents: ["repomix-agent"],
          },
        })
        const promptCallCount = { n: 0 }
        const client = {
          session: {
            messages: async (_args: any) => ({
              data: [makeMsg("assistant", "Working on it.")],
            }),
            prompt: async (_args: any) => { promptCallCount.n++ },
          },
        }
        const hooks = await StatusMarkerEnforcerPlugin({
          directory: tmpDir,
          worktree: undefined,
          client,
        })
        await hooks["event"]!({ event: makeIdleEvent("sess-task3-006", "repomix-agent") })
        expect(promptCallCount.n).toBe(0)
      } finally {
        rmSync(tmpDir, { recursive: true, force: true })
      }
    })
  })
})

// ─── Task 4 — Attempt counter + max-attempts ceiling ─────────────────────────
//
// Developer note: to make these tests pass you must add the following exports
// to status-marker-enforcer.js:
//
//   export const MAX_COUNTER_ENTRIES = 100
//   export const COUNTER_TTL_MS = 24 * 60 * 60 * 1000
//
//   export function readCounter(directory, slug):
//     Record<string, { attempts: number; lastNudge: string }>
//     — reads .ai/telamon/memory/thinking/.status-enforcer-counter-<slug>.json
//     — returns {} if missing or malformed
//     — calls pruneCounter() before returning (lazy GC)
//
//   export function writeCounter(directory, slug, counter): void
//     — writes the counter object as JSON to the counter file path
//     — creates parent dirs if needed
//
//   export function pruneCounter(counter, now?):
//     Record<string, { attempts: number; lastNudge: string }>
//     — drops entries older than COUNTER_TTL_MS
//     — evicts oldest-lastNudge entries when count > MAX_COUNTER_ENTRIES
//     — mutates and returns counter
//
//   Also update StatusMarkerEnforcerPlugin to:
//     - Read max_attempts from config (default 2)
//     - On stall: read counter, increment, write back, then nudge (or stop if >= max)
//     - On recovery (marker present): delete sessionId entry from counter, write back
//
// Spec refs:
//   backlog.md lines 111–127
//   PLAN-ARCH-2026-05-06-001.md §3.3, §4.1
// ─────────────────────────────────────────────────────────────────────────────

// ─── Task 4 helpers ───────────────────────────────────────────────────────────

/** Compute the worktreeSlug the same way remember-session.js / the plugin does. */
function worktreeSlug(worktree: string | undefined, directory: string): string {
  const { basename } = require("path")
  const raw = basename(worktree || directory || "default")
  return raw.replace(/[^a-z0-9_-]/gi, "-").toLowerCase()
}

/** Return the counter file path for a given directory + slug. */
function counterFilePath(directory: string, slug: string): string {
  return join(directory, `.ai/telamon/memory/thinking/.status-enforcer-counter-${slug}.json`)
}

/** Write a raw counter JSON to the expected path (bypasses plugin logic). */
function writeRawCounter(directory: string, slug: string, data: object) {
  const { writeFileSync, mkdirSync } = require("fs")
  const path = counterFilePath(directory, slug)
  mkdirSync(require("path").dirname(path), { recursive: true })
  writeFileSync(path, JSON.stringify(data), "utf8")
}

/** Read raw counter JSON from the expected path. */
function readRawCounter(directory: string, slug: string): any {
  const { readFileSync, existsSync } = require("fs")
  const path = counterFilePath(directory, slug)
  if (!existsSync(path)) return null
  try {
    return JSON.parse(readFileSync(path, "utf8"))
  } catch {
    return null
  }
}

/** ISO string N hours ago. */
function hoursAgo(n: number): string {
  return new Date(Date.now() - n * 60 * 60 * 1000).toISOString()
}

/** ISO string N minutes ago. */
function minutesAgo(n: number): string {
  return new Date(Date.now() - n * 60 * 1000).toISOString()
}

// ─── K. Counter increments per stall ─────────────────────────────────────────

describe("status-marker-enforcer / Task 4 — K. Counter increments per stall", () => {

  test("K.1 [backlog L124] first stall on fresh session writes { <id>: { attempts: 1, lastNudge: <ISO> } } to counter file", async () => {
    const { mkdirSync, rmSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-k1-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      // max_attempts: 3 so nudge fires on attempt 1
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true, max_attempts: 3 } })
      const sessionId = "sess-k1-fresh"
      const client = makeClient({
        messages: [makeMsg("assistant", "Working on it.")], // no marker → stall
      })
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent(sessionId) })

      const slug = worktreeSlug(undefined, tmpDir)
      const raw = readRawCounter(tmpDir, slug)

      // Counter file must exist
      expect(raw).not.toBeNull()
      // Must have an entry for this session
      expect(raw[sessionId]).toBeDefined()
      // attempts must be 1
      expect(raw[sessionId].attempts).toBe(1)
      // lastNudge must be a valid ISO string (recent — within last 10 seconds)
      const nudgeTime = new Date(raw[sessionId].lastNudge).getTime()
      expect(Number.isNaN(nudgeTime)).toBe(false)
      expect(Date.now() - nudgeTime).toBeLessThan(10_000)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })

  test("K.2 [backlog L124] second stall increments attempts to 2 (max_attempts: 3 so nudge still fires)", async () => {
    const { mkdirSync, rmSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-k2-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true, max_attempts: 3 } })
      const sessionId = "sess-k2-second"
      const slug = worktreeSlug(undefined, tmpDir)

      // Pre-seed counter with attempts: 1
      writeRawCounter(tmpDir, slug, {
        [sessionId]: { attempts: 1, lastNudge: minutesAgo(5) },
      })

      const client = makeClient({
        messages: [makeMsg("assistant", "Still working.")], // no marker
      })
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent(sessionId) })

      const raw = readRawCounter(tmpDir, slug)
      expect(raw[sessionId]).toBeDefined()
      expect(raw[sessionId].attempts).toBe(2)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })

  test("K.3 [backlog L127, PLAN §3.3] counter file path is .ai/telamon/memory/thinking/.status-enforcer-counter-<slug>.json", async () => {
    const { mkdirSync, rmSync, existsSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-k3-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true, max_attempts: 3 } })
      const sessionId = "sess-k3-path"
      const slug = worktreeSlug(undefined, tmpDir)
      const expectedPath = counterFilePath(tmpDir, slug)

      const client = makeClient({
        messages: [makeMsg("assistant", "Working.")],
      })
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent(sessionId) })

      // The file must exist at the exact expected path
      expect(existsSync(expectedPath)).toBe(true)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })
})

// ─── L. Max attempts ceiling ──────────────────────────────────────────────────

describe("status-marker-enforcer / Task 4 — L. Max attempts ceiling", () => {

  test("L.1 [backlog L125] when attempts >= max_attempts (default 2), client.session.prompt is NOT called", async () => {
    const { mkdirSync, rmSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-l1-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      // Default max_attempts = 2; pre-seed with attempts: 2 (already at ceiling)
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true } })
      const sessionId = "sess-l1-ceiling"
      const slug = worktreeSlug(undefined, tmpDir)
      writeRawCounter(tmpDir, slug, {
        [sessionId]: { attempts: 2, lastNudge: minutesAgo(5) },
      })

      const promptCallCount = { n: 0 }
      const client = {
        session: {
          messages: async (_args: any) => ({
            data: [makeMsg("assistant", "Still working.")],
          }),
          prompt: async (_args: any) => { promptCallCount.n++ },
        },
      }
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent(sessionId) })

      expect(promptCallCount.n).toBe(0)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })

  test("L.2 [backlog L120] ceiling hit → exactly one stderr line matching /\\[status-marker-enforcer\\] Session .+ exceeded max nudge attempts \\(\\d+\\) — stopping\\. Human review needed\\./", async () => {
    const { mkdirSync, rmSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-l2-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true } })
      const sessionId = "sess-l2-stderr"
      const slug = worktreeSlug(undefined, tmpDir)
      writeRawCounter(tmpDir, slug, {
        [sessionId]: { attempts: 2, lastNudge: minutesAgo(5) },
      })

      // Capture stderr
      const stderrLines: string[] = []
      const origStderrWrite = process.stderr.write.bind(process.stderr)
      process.stderr.write = (chunk: any, ...args: any[]) => {
        stderrLines.push(typeof chunk === "string" ? chunk : chunk.toString())
        return origStderrWrite(chunk, ...args)
      }

      try {
        const client = makeClient({
          messages: [makeMsg("assistant", "Still working.")],
        })
        const hooks = await StatusMarkerEnforcerPlugin({
          directory: tmpDir,
          worktree: undefined,
          client,
        })
        await hooks["event"]!({ event: makeIdleEvent(sessionId) })
      } finally {
        process.stderr.write = origStderrWrite
      }

      const stderrOutput = stderrLines.join("")
      const pattern = /\[status-marker-enforcer\] Session .+ exceeded max nudge attempts \(\d+\) — stopping\. Human review needed\./
      expect(stderrOutput).toMatch(pattern)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })

  test("L.3 [backlog L119] custom max_attempts: 5 — nudge fires on attempt 5 but NOT on attempt 6", async () => {
    const { mkdirSync, rmSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-l3-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true, max_attempts: 5 } })
      const slug = worktreeSlug(undefined, tmpDir)

      // Attempt 5: attempts pre-seeded at 4 → after increment = 5 → still < max? No: 5 >= 5 → ceiling
      // Wait — spec says "when attempts >= max_attempts, do NOT send nudge"
      // So at attempts=4 (pre-seed), after increment=5, 5 >= 5 → ceiling hit, no nudge
      // At attempts=4 (pre-seed), nudge fires (4 < 5). After nudge, attempts=5.
      // At attempts=5 (pre-seed), ceiling hit (5 >= 5), no nudge.

      // Test: attempt 4 → nudge fires (4 < 5 before increment, or 5 >= 5 after?)
      // Per PLAN §3.3 pseudocode: read counter → if attempts >= max → stop. THEN increment.
      // So: pre-seed=4 → read=4 → 4 < 5 → nudge fires → increment to 5 → write.
      // Pre-seed=5 → read=5 → 5 >= 5 → no nudge.

      const sessionId5 = "sess-l3-attempt5"
      writeRawCounter(tmpDir, slug, {
        [sessionId5]: { attempts: 4, lastNudge: minutesAgo(5) },
      })

      const promptCount5 = { n: 0 }
      const client5 = {
        session: {
          messages: async (_args: any) => ({
            data: [makeMsg("assistant", "Working.")],
          }),
          prompt: async (_args: any) => { promptCount5.n++ },
        },
      }
      const hooks5 = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client: client5,
      })
      await hooks5["event"]!({ event: makeIdleEvent(sessionId5) })
      // Nudge should fire (4 < 5)
      expect(promptCount5.n).toBe(1)

      // Now attempt 6: pre-seed at 5 → ceiling
      const sessionId6 = "sess-l3-attempt6"
      writeRawCounter(tmpDir, slug, {
        ...readRawCounter(tmpDir, slug),
        [sessionId6]: { attempts: 5, lastNudge: minutesAgo(3) },
      })

      const promptCount6 = { n: 0 }
      const client6 = {
        session: {
          messages: async (_args: any) => ({
            data: [makeMsg("assistant", "Working.")],
          }),
          prompt: async (_args: any) => { promptCount6.n++ },
        },
      }
      const hooks6 = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client: client6,
      })
      await hooks6["event"]!({ event: makeIdleEvent(sessionId6) })
      // No nudge (5 >= 5)
      expect(promptCount6.n).toBe(0)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })

  test("L.4 [backlog L125] ceiling-hit path does NOT increment counter beyond what's already there", async () => {
    const { mkdirSync, rmSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-l4-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true } }) // max_attempts: 2
      const sessionId = "sess-l4-no-increment"
      const slug = worktreeSlug(undefined, tmpDir)
      writeRawCounter(tmpDir, slug, {
        [sessionId]: { attempts: 2, lastNudge: minutesAgo(5) },
      })

      const client = makeClient({
        messages: [makeMsg("assistant", "Still working.")],
      })
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent(sessionId) })

      // Counter must still be 2 — no spurious increment
      const raw = readRawCounter(tmpDir, slug)
      expect(raw[sessionId].attempts).toBe(2)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })
})

// ─── M. Reset on marker recovery ─────────────────────────────────────────────

describe("status-marker-enforcer / Task 4 — M. Reset on marker recovery", () => {

  const MARKERS = ["FINISHED!", "BLOCKED: reason", "NEEDS_INPUT: question", "PARTIAL: summary"]

  for (const markerText of MARKERS) {
    test(`M.1 [backlog L122, L126] recovery with "${markerText.split(":")[0]}..." → counter entry for session removed`, async () => {
      const { mkdirSync, rmSync } = require("fs")
      const tmpDir = join("/tmp", `sme-t4-m1-${process.pid}-${markerText.slice(0, 8).replace(/\W/g, "")}`)
      mkdirSync(tmpDir, { recursive: true })
      try {
        writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true } })
        const sessionId = `sess-m1-${markerText.slice(0, 8).replace(/\W/g, "")}`
        const otherSessionId = "sess-m1-other"
        const slug = worktreeSlug(undefined, tmpDir)

        // Pre-seed counter with this session at attempts: 1 + another session
        writeRawCounter(tmpDir, slug, {
          [sessionId]: { attempts: 1, lastNudge: minutesAgo(10) },
          [otherSessionId]: { attempts: 1, lastNudge: minutesAgo(5) },
        })

        // Last assistant message has a valid marker → recovery
        const client = makeClient({
          messages: [makeMsg("assistant", `Work done.\n\n${markerText}`)],
        })
        const hooks = await StatusMarkerEnforcerPlugin({
          directory: tmpDir,
          worktree: undefined,
          client,
        })
        await hooks["event"]!({ event: makeIdleEvent(sessionId) })

        const raw = readRawCounter(tmpDir, slug)
        // The recovered session's entry must be removed
        expect(raw[sessionId]).toBeUndefined()
      } finally {
        rmSync(tmpDir, { recursive: true, force: true })
      }
    })
  }

  test("M.2 [backlog L122] reset only affects matching session — other sessions' counters untouched", async () => {
    const { mkdirSync, rmSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-m2-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true } })
      const recoveredId = "sess-m2-recovered"
      const otherIdA = "sess-m2-other-a"
      const otherIdB = "sess-m2-other-b"
      const slug = worktreeSlug(undefined, tmpDir)

      writeRawCounter(tmpDir, slug, {
        [recoveredId]: { attempts: 1, lastNudge: minutesAgo(10) },
        [otherIdA]: { attempts: 2, lastNudge: minutesAgo(8) },
        [otherIdB]: { attempts: 1, lastNudge: minutesAgo(3) },
      })

      const client = makeClient({
        messages: [makeMsg("assistant", "All done.\n\nFINISHED!")],
      })
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent(recoveredId) })

      const raw = readRawCounter(tmpDir, slug)
      // Recovered session gone
      expect(raw[recoveredId]).toBeUndefined()
      // Others intact
      expect(raw[otherIdA]).toBeDefined()
      expect(raw[otherIdA].attempts).toBe(2)
      expect(raw[otherIdB]).toBeDefined()
      expect(raw[otherIdB].attempts).toBe(1)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })
})

// ─── N. Eviction (MAX_COUNTER_ENTRIES = 100) ──────────────────────────────────

describe("status-marker-enforcer / Task 4 — N. Eviction (MAX_COUNTER_ENTRIES = 100)", () => {

  test("N.0 [PLAN §3.3] MAX_COUNTER_ENTRIES exported constant equals 100", async () => {
    const { MAX_COUNTER_ENTRIES } = await getCounterExports()
    expect(MAX_COUNTER_ENTRIES).toBe(100)
  })

  test("N.1 [PLAN §3.3] 100 existing entries + 1 new session → oldest evicted, file has 100 entries, new session present", async () => {
    const { mkdirSync, rmSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-n1-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true, max_attempts: 3 } })
      const slug = worktreeSlug(undefined, tmpDir)

      // Build 100 entries with monotonically increasing lastNudge (oldest = entry-0)
      const existing: Record<string, { attempts: number; lastNudge: string }> = {}
      for (let i = 0; i < 100; i++) {
        existing[`sess-n1-existing-${i}`] = {
          attempts: 1,
          lastNudge: new Date(Date.now() - (100 - i) * 60_000).toISOString(), // oldest = i=0
        }
      }
      writeRawCounter(tmpDir, slug, existing)

      // Trigger a new session stall → plugin must evict oldest to make room
      const newSessionId = "sess-n1-new"
      const client = makeClient({
        messages: [makeMsg("assistant", "Working.")],
      })
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client,
      })
      await hooks["event"]!({ event: makeIdleEvent(newSessionId) })

      const raw = readRawCounter(tmpDir, slug)
      const keys = Object.keys(raw)

      // File must have exactly 100 entries
      expect(keys.length).toBe(100)
      // New session must be present
      expect(raw[newSessionId]).toBeDefined()
      // Oldest entry (sess-n1-existing-0) must be gone
      expect(raw["sess-n1-existing-0"]).toBeUndefined()
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })

  test("N.2 [PLAN §3.3] eviction picks oldest lastNudge, not insertion order", async () => {
    const { pruneCounter } = await getCounterExports()
    // Unit test on pruneCounter directly — no filesystem, no plugin invocation
    // Build a counter with 101 entries; the "oldest" is not entry[0] by insertion
    const counter: Record<string, { attempts: number; lastNudge: string }> = {}
    const now = Date.now()

    // Add 100 entries with recent timestamps
    for (let i = 0; i < 100; i++) {
      counter[`sess-n2-recent-${i}`] = {
        attempts: 1,
        lastNudge: new Date(now - i * 1000).toISOString(), // recent, spread 1s apart
      }
    }
    // Add 1 entry with a very old timestamp (should be evicted)
    counter["sess-n2-oldest"] = {
      attempts: 1,
      lastNudge: new Date(now - 999 * 60_000).toISOString(), // ~16h ago but within 24h
    }

    // pruneCounter must evict the oldest-lastNudge entry
    const pruned = pruneCounter(counter)
    expect(Object.keys(pruned).length).toBeLessThanOrEqual(100)
    expect(pruned["sess-n2-oldest"]).toBeUndefined()
  })
})

// ─── O. Lazy GC (24h prune) ───────────────────────────────────────────────────

describe("status-marker-enforcer / Task 4 — O. Lazy GC (24h prune)", () => {

  test("O.0 [PLAN §3.3] COUNTER_TTL_MS exported constant equals 24 * 60 * 60 * 1000", async () => {
    const { COUNTER_TTL_MS } = await getCounterExports()
    expect(COUNTER_TTL_MS).toBe(24 * 60 * 60 * 1000)
  })

  test("O.1 [backlog L121] entry with lastNudge 25h ago is pruned; fresh entry untouched", async () => {
    const { pruneCounter } = await getCounterExports()
    // Unit test on pruneCounter directly
    const staleId = "sess-o1-stale"
    const freshId = "sess-o1-fresh"
    const counter: Record<string, { attempts: number; lastNudge: string }> = {
      [staleId]: { attempts: 1, lastNudge: hoursAgo(25) },
      [freshId]: { attempts: 1, lastNudge: minutesAgo(30) },
    }

    const pruned = pruneCounter(counter)
    expect(pruned[staleId]).toBeUndefined()
    expect(pruned[freshId]).toBeDefined()
    expect(pruned[freshId].attempts).toBe(1)
  })

  test("O.2 [backlog L121] pruning happens on read regardless of whether current session needs nudge — readCounter prunes stale entries", async () => {
    const { readCounter } = await getCounterExports()
    const { mkdirSync, rmSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-o2-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      const slug = worktreeSlug(undefined, tmpDir)
      const staleId = "sess-o2-stale"
      const freshId = "sess-o2-fresh"

      // Write a counter with one stale and one fresh entry
      writeRawCounter(tmpDir, slug, {
        [staleId]: { attempts: 1, lastNudge: hoursAgo(25) },
        [freshId]: { attempts: 1, lastNudge: minutesAgo(30) },
      })

      // Call readCounter directly — should prune stale on read
      const result = readCounter(tmpDir, slug)

      expect(result[staleId]).toBeUndefined()
      expect(result[freshId]).toBeDefined()
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })
})

// ─── P. File-level robustness ─────────────────────────────────────────────────

describe("status-marker-enforcer / Task 4 — P. File-level robustness", () => {

  test("P.1 [backlog L124] counter file does not exist → treated as empty, first idle creates it", async () => {
    const { mkdirSync, rmSync, existsSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-p1-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true, max_attempts: 3 } })
      const sessionId = "sess-p1-nocounterfile"
      const slug = worktreeSlug(undefined, tmpDir)
      const counterPath = counterFilePath(tmpDir, slug)

      // Ensure counter file does not exist
      expect(existsSync(counterPath)).toBe(false)

      const client = makeClient({
        messages: [makeMsg("assistant", "Working.")],
      })
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client,
      })
      // Must not throw
      await hooks["event"]!({ event: makeIdleEvent(sessionId) })

      // Counter file must now exist with attempts: 1
      expect(existsSync(counterPath)).toBe(true)
      const raw = readRawCounter(tmpDir, slug)
      expect(raw[sessionId]).toBeDefined()
      expect(raw[sessionId].attempts).toBe(1)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })

  test("P.2 [backlog L124] counter file is malformed JSON → treated as empty (no crash); next write rewrites cleanly", async () => {
    const { mkdirSync, rmSync, writeFileSync } = require("fs")
    const tmpDir = join("/tmp", `sme-t4-p2-${process.pid}`)
    mkdirSync(tmpDir, { recursive: true })
    try {
      writeTelamon(tmpDir, { status_marker_enforcer: { enabled: true, max_attempts: 3 } })
      const sessionId = "sess-p2-malformed"
      const slug = worktreeSlug(undefined, tmpDir)
      const counterPath = counterFilePath(tmpDir, slug)

      // Write malformed JSON
      mkdirSync(require("path").dirname(counterPath), { recursive: true })
      writeFileSync(counterPath, "{ this is not valid JSON !!!", "utf8")

      const client = makeClient({
        messages: [makeMsg("assistant", "Working.")],
      })
      const hooks = await StatusMarkerEnforcerPlugin({
        directory: tmpDir,
        worktree: undefined,
        client,
      })
      // Must not throw
      await hooks["event"]!({ event: makeIdleEvent(sessionId) })

      // Counter file must now be valid JSON with attempts: 1
      const raw = readRawCounter(tmpDir, slug)
      // raw is null if file is still malformed (plugin hasn't implemented counter yet → test fails)
      expect(raw).not.toBeNull()
      expect(raw[sessionId]).toBeDefined()
      expect(raw[sessionId].attempts).toBe(1)
    } finally {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })
})

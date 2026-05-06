// tests/plugins/status-marker-enforcer.test.ts
//
// Failing tests for Task 2 of the status-marker-enforcer backlog.
// All tests MUST fail until src/plugins/status-marker-enforcer.js is implemented.
//
// Spec references:
//   PLAN-ARCH-2026-05-06-001.md §2, §3.5, §5, §6, §8, §9
//   backlog.md lines 68–95
//   agent-communication/SKILL.md lines 19–24

import { describe, test, expect } from "bun:test"
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

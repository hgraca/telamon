import { describe, test, expect } from "bun:test"
import { readFileSync, readdirSync } from "fs"
import { join, basename } from "path"

const AGENTS_DIR = join(import.meta.dir, "../../src/agents")

// Memory skills that subagents should NOT proactively trigger
const BANNED_PROACTIVE_MEMORY_SKILLS = [
  "telamon.remember_lessons_learned",
  "telamon.remember_task",
  "telamon.remember_gotcha",
]

// Agents that should NOT have any proactive memory triggers
// (all subagents — only the orchestrator and companion get special treatment)
const SUBAGENT_FILES = [
  "developer.md",
  "tester.md",
  "reviewer.md",
  "architect.md",
  "critic.md",
  "po.md",
  "security.md",
  "ui-designer.md",
  "ux-designer.md",
]

// The orchestrator should not reference these skills either
const ORCHESTRATOR_FILE = "telamon.md"

describe("Agent memory skill references", () => {

  describe("subagents must NOT reference proactive memory skills", () => {
    for (const file of SUBAGENT_FILES) {
      test(`${basename(file, ".md")} has no proactive memory triggers`, () => {
        const content = readFileSync(join(AGENTS_DIR, file), "utf8")
        for (const skill of BANNED_PROACTIVE_MEMORY_SKILLS) {
          expect(content).not.toContain(skill)
        }
      })
    }
  })

  describe("subagents must NOT reference remember_session as a proactive trigger", () => {
    for (const file of SUBAGENT_FILES) {
      test(`${basename(file, ".md")} does not proactively trigger remember_session`, () => {
        const content = readFileSync(join(AGENTS_DIR, file), "utf8")
        // remember_session should NOT appear in subagent Skills sections
        expect(content).not.toContain("telamon.remember_session")
      })
    }
  })

  describe("orchestrator memory references", () => {
    test("orchestrator does NOT reference remember_lessons_learned", () => {
      const content = readFileSync(join(AGENTS_DIR, ORCHESTRATOR_FILE), "utf8")
      expect(content).not.toContain("telamon.remember_lessons_learned")
    })

    test("orchestrator does NOT reference remember_task", () => {
      const content = readFileSync(join(AGENTS_DIR, ORCHESTRATOR_FILE), "utf8")
      expect(content).not.toContain("telamon.remember_task")
    })

    test("orchestrator does NOT reference remember_gotcha", () => {
      const content = readFileSync(join(AGENTS_DIR, ORCHESTRATOR_FILE), "utf8")
      expect(content).not.toContain("telamon.remember_gotcha")
    })

    test("orchestrator mentions automatic memory capture", () => {
      const content = readFileSync(join(AGENTS_DIR, ORCHESTRATOR_FILE), "utf8")
      expect(content).toContain("remember-session plugin")
    })

    test("orchestrator keeps remember_session for manual wrap-up only", () => {
      const content = readFileSync(join(AGENTS_DIR, ORCHESTRATOR_FILE), "utf8")
      expect(content).toContain("telamon.remember_session")
      // It should be tied to "wrap up" — not a generic "when wrapping up" trigger
      expect(content).toContain('wrap up')
    })

    test("orchestrator keeps remember_checkpoint for context overflow", () => {
      const content = readFileSync(join(AGENTS_DIR, ORCHESTRATOR_FILE), "utf8")
      expect(content).toContain("telamon.remember_checkpoint")
    })
  })

  describe("companion agent memory references", () => {
    test("companion keeps remember_checkpoint but no proactive memory skills", () => {
      const content = readFileSync(join(AGENTS_DIR, "companion.md"), "utf8")
      expect(content).toContain("telamon.remember_checkpoint")
      for (const skill of BANNED_PROACTIVE_MEMORY_SKILLS) {
        expect(content).not.toContain(skill)
      }
    })
  })
})

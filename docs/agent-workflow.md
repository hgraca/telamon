---
layout: page
title: Agent Workflow
description: How Telamon classifies requests, routes to specialists, and manages the full agent lifecycle.
nav_section: docs
---

How the orchestrator processes every request — from session bootstrap through classification,
routing, delegation, post-work gates, and memory capture.

## Contents

1. [Session Bootstrap](#1-session-bootstrap)
2. [Request Classification](#2-request-classification)
3. [Handle Directly](#3-handle-directly)
4. [Delegate to Specialist](#4-delegate-to-specialist)
5. [Post-Delegation Signal Handling](#5-post-delegation-signal-handling)
6. [Mandatory Post-Work Gates](#6-mandatory-post-work-gates)
7. [Routing Decision Tree](#7-routing-decision-tree)
8. [Memory Capture & Compaction](#8-memory-capture--compaction)
9. [Agents and Their Roles](#9-agents-and-their-roles)
10. [Communication Protocol](#10-communication-protocol)

---

## 1. Session Bootstrap

Before any user request, Telamon runs a mandatory start sequence.

```
  AGENTS.md loaded by opencode
       |
       v
  +-----------------------------+
  | Inline bootstrap files      | Loaded via system prompt:
  | (Instructions from:)        |   .ai/telamon/memory/bootstrap/memory.md
  |                             |   .ai/telamon/memory/bootstrap/project-rules.md
  |                             |   .ai/telamon/memory/bootstrap/mcp.md
  |                             |   .ai/telamon/memory/bootstrap/caveman.md
  +-----------------------------+
       |
       v
  +--------------------------------+
  | Read .ai/telamon/telamon.jsonc | Check caveman_enabled, project_name, etc.
  +--------------------------------+
       |
       v
  +-----------------------------+
  | Read .ai/telamon/memory/     |
  |   project-rules/**/*.md      | Project-specific rules
  +-----------------------------+
       |
       v
  +-------------------------------+
  | Load skill: recall_memories   |
  |   1. Recall past context      |
  |   2. Update vault index (QMD) |
  |   3. Self-initialize          |
  |   4. Retrieval priority table |
  +-------------------------------+
       |
       | (detail below)
       v
  +-------------------------------------------------------------------+
  | Step 1: Recall past context                                       |
  |                                                                   |
  |  a) Read brain/ notes directly (small, always relevant):          |
  |     +---------------------------+-------------------------------+ |
  |     | File                      | When to read                  | |
  |     +---------------------------+-------------------------------+ |
  |     | brain/key_decisions.md    | Before arch work or           | |
  |     |                           | stakeholder answer lookup     | |
  |     | brain/patterns.md         | Before writing new code       | |
  |     | brain/gotchas.md          | Before touching known         | |
  |     |                           | problem areas                 | |
  |     | brain/memories.md         | Do NOT read at start;         | |
  |     |                           | search via QMD                | |
  |     |                           | when needed later             | |
  |     +---------------------------+-------------------------------+ |
  +-------------------------------------------------------------------+
       |
       v
  +-------------------------------------------------------------------+
  | Step 2: Update vault index (QMD)                                  |
  |                                                                   |
  |  QMD = local markdown search engine over .ai/telamon/memory/      |
  |                                                                   |
  |  Provides three search modes:                                     |
  |    lex  — BM25 keyword search (exact terms, phrases, exclusions)  |
  |    vec  — semantic vector search (natural language questions)      |
  |    hyde — hypothetical document search (write what answer          |
  |           looks like, 50-100 words)                                |
  |                                                                   |
  |  Initialize: ensure QMD index is up to date                       |
  |  Query: qmd_query with searches array                             |
  |  Retrieve: qmd_get by path or docid                               |
  |                                                                   |
  |  Used later for: vault semantic search ("did we ever..."),        |
  |  specs, ADRs, requirements lookup                                 |
  +-------------------------------------------------------------------+
       |
       v
  +-------------------------------------------------------------------+
  | Step 3: Self-initialize (check each time, build if missing)       |
  |                                                                   |
  |  a) Graphify knowledge graph:                                     |
  |     Check: graphify-out/GRAPH_REPORT.md exists?                   |
  |       NO  → run `/graphify .` (one-time build, full pipeline)     |
  |       YES → read GRAPH_REPORT.md before touching architecture     |
  |     Provides: god nodes, community structure, surprising          |
  |     connections, architecture relationships                       |
  |                                                                   |
  |  b) Semantic codebase index:                                      |
  |     Check: .opencode/index/ exists?                               |
  |       NO  → call `index_codebase` tool (one-time build)           |
  |       YES → index is ready                                        |
  |     Provides: code search by meaning (not keywords),              |
  |     implementation lookup, call graph, similar code finder         |
  +-------------------------------------------------------------------+
       |
       v
  +-------------------------------+
  | If caveman_enabled = true     |
  |   Load caveman skill          |
  | Else: normal communication    |
  +-------------------------------+
       |
       v
  ~~~ READY FOR USER REQUESTS ~~~
```

---

## 2. Request Classification

Every request is classified on two axes before routing.

```
  User Request
       |
       v
  +-----------------------------------+
  | CLASSIFY on two axes:             |
  |                                   |
  |  Work Type:                       |
  |    Question | Documentation       |
  |    Meta | Code fix | Testing      |
  |    Review | Architecture          |
  |    Design | Audit | Security      |
  |    Story | Epic                   |
  |                                   |
  |  Work Size:                       |
  |    Trivial | Small                |
  |    Medium  | Large                |
  +-----------------------------------+
       |
       v
  +-----------------------------------+
  | ROUTE based on type + size        |
  +-----------------------------------+
       |
       +----------+----------+
       |                     |
  HANDLE DIRECTLY       DELEGATE TO
  (Telamon acts)        SPECIALIST
```

### Routing Matrix — Type × Size → Destination

```
  +================+==========+====================+====================+===================+
  | Work Type      | Trivial  | Small              | Medium             | Large             |
  +================+==========+====================+====================+===================+
  | Question       | SELF     | SELF               | SELF               | SELF              |
  |                | (read,   | (read, search,     | (read, search,     | (read, search,    |
  |                |  answer) |  answer)           |  answer)           |  answer)          |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Documentation  | SELF     | SELF               | SELF               | SELF              |
  |                | (gate:   | (gate:             | (gate:             | (gate:            |
  |                |  doc_    |  doc_rules)        |  doc_rules)        |  doc_rules)       |
  |                |  rules)  |                    |                    |                   |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Meta           | SELF     | SELF               | SELF               | SELF              |
  |                |          | (gate: optimize-   | (gate: optimize-   | (gate: optimize-  |
  |                |          |  instructions)     |  instructions)     |  instructions)    |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Code fix       | SELF     | implement_story    | SELF (planning)    | SELF (planning)   |
  |                | (explain | cycle:             | → implement_story  | → implement_story |
  |                |  or do   | @tester→@developer | cycle:             | cycle:            |
  |                |  inline) | →@reviewer         | @tester→@developer | @tester→@developer|
  |                |          |                    | →@reviewer         | →@reviewer        |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Testing        | SELF     | @tester            | @tester            | @tester           |
  |                | (answer  |                    |                    |                   |
  |                |  about   |                    |                    |                   |
  |                |  tests)  |                    |                    |                   |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Review         | SELF     | @reviewer          | @reviewer          | @reviewer         |
  |                | (quick   |                    |                    |                   |
  |                |  opinion)|                    |                    |                   |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Architecture   | SELF     | @architect         | @architect         | @architect        |
  |                | (answer  |                    |                    |                   |
  |                |  arch Q) |                    |                    |                   |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Design (UX)    | SELF     | @ux-designer       | @ux-designer       | @ux-designer      |
  |                | (answer) |                    |                    |                   |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Design (UI)    | SELF     | @ui-designer       | @ui-designer       | @ui-designer      |
  |                | (answer) |                    |                    |                   |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Audit          | SELF     | @critic            | @critic            | @critic           |
  |                | (answer) |                    |                    |                   |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Security       | SELF     | @security          | @security          | @security         |
  |                | (answer) |                    |                    |                   |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Story          | —        | implement_story    | SELF leads:        | SELF leads:       |
  |                | (not a   | (if trivial plan,  | plan_story         | plan_story        |
  |                |  story)  | skip planning)     | (@po, @architect,  | (@po, @architect, |
  |                |          |                    |  @critic, opt:     |  @critic, opt:    |
  |                |          |                    |  @ux/@ui-designer) |  @ux/@ui-designer)|
  |                |          |                    | → implement_story  | → implement_story |
  |                |          |                    | (@tester,@developer| (@tester,@developer|
  |                |          |                    |  ,@reviewer)       |  ,@reviewer)      |
  +----------------+----------+--------------------+--------------------+-------------------+
  | Epic           | —        | —                  | —                  | SELF leads:       |
  |                | (not     | (not an epic)      | (reclassify as     | epic skill        |
  |                |  epic)   |                    |  story)            | @po breaks into   |
  |                |          |                    |                    | stories, then     |
  |                |          |                    |                    | plan+implement    |
  |                |          |                    |                    | each sequentially |
  +================+==========+====================+====================+===================+

  Legend:
    SELF         = Telamon handles directly (no subagent)
    @agent       = Delegate to that specialist agent
    implement_   = Follow the implement_story skill
      story        (Tester → Developer → Reviewer cycle)
    plan_story   = Follow the plan_story skill
                   (orchestrate planning subagents)
    epic skill   = Follow the epic skill
                   (plan_story per story, then implement)
    gate:        = Must load that skill BEFORE acting
    →            = "then" (sequential)
```

### Key Routing Rules

| # | Rule | Detail |
|---|------|--------|
| 1 | Trivial = answer only | Any trivial request is answered directly. No delegation. No code changes. |
| 2 | Small code → implement_story | Small code fixes and PR review comments ALWAYS go through the full Tester→Developer→Reviewer cycle. Never @developer alone. |
| 3 | Medium+ code → plan first | Telamon leads the planning (may invoke @architect if complex). Implementation still follows the full cycle. |
| 4 | Story = plan_story + implement_story | Always plan first with multiple specialists. Then implement via the standard cycle. |
| 5 | Epic = break into stories | @po breaks epic into stories. Each story follows Rule 4. Stories are implemented sequentially. |
| 6 | Specialist types always delegate | Testing/Review/Arch/Design/Audit/Security always go to the matching specialist. Exception: trivial → SELF. |
| 7 | Product questions → @po | Requirements clarification, domain semantics, acceptance criteria, task prioritization. |

---

## 3. Handle Directly

Work that Telamon performs itself without delegating.

```
  +--------------------------------------------------------------------+
  | HANDLE DIRECTLY                                                    |
  |                                                                    |
  |  +-----------------------+   +-------------------------------+     |
  |  | Question              |   | Documentation                 |     |
  |  | (any size)            |   | (any size)                    |     |
  |  |                       |   |                               |     |
  |  | Read code, search,    |   | Gate: load documentation_     |     |
  |  | answer using:         |   |   rules skill first           |     |
  |  | - codebase-index      |   | Write/edit .md files          |     |
  |  | - grep / read tools   |   | Check 100-line limit          |     |
  |  | - graphify / QMD      |   | Update README TOC if needed   |     |
  |  +-----------------------+   +-------------------------------+     |
  |                                                                    |
  |  +-----------------------+   +-------------------------------+     |
  |  | Meta work             |   | Stories / Epics               |     |
  |  | (any size)            |   | (medium/large)                |     |
  |  |                       |   |                               |     |
  |  | Gate: load optimize-  |   | Lead planning + implement     |     |
  |  |   instructions skill  |   | workflows directly            |     |
  |  |   first (if editing   |   | (see sections 5 & 6 below)   |     |
  |  |   agent/skill files)  |   | Consult @po as needed         |     |
  |  | Manage vault/memory   |   |                               |     |
  |  +-----------------------+   +-------------------------------+     |
  |                                                                    |
  |  +-----------------------+                                         |
  |  | Code fix (medium+)    |                                         |
  |  | (needs planning)      |                                         |
  |  |                       |                                         |
  |  | Lead planning workflow|                                         |
  |  | then delegate impl    |                                         |
  |  +-----------------------+                                         |
  +--------------------------------------------------------------------+
```

---

## 4. Delegate to Specialist

When work is routed to a subagent, Telamon loads the `agent-communication` skill
and constructs a structured delegation prompt.

```
  +------------------------------------------------------------------------+
  | DELEGATE TO SPECIALIST                                                 |
  | (Load agent-communication skill for delegation format)                 |
  |                                                                        |
  |  Request Type             Delegate To       Workflow / Notes           |
  |  ======================== ================= ========================== |
  |  Code fix (small)         implement_story   Tester->Developer->        |
  |  PR review comments       implement_story     Reviewer cycle           |
  |                                             (NOT @developer alone)     |
  |  ---------------------------------------------------------------      |
  |  Testing                  @tester           Write/fix/audit tests      |
  |  Review                   @reviewer         Review changeset or PR     |
  |  Architecture             @architect        ADRs, design decisions     |
  |  UX design                @ux-designer      User flows, interactions   |
  |  UI design                @ui-designer      Visual specs, tokens       |
  |  Audit                    @critic           Pattern drift, consistency |
  |  Security                 @security         Threat model, vulns, auth  |
  |  Product question         @po               Domain, requirements       |
  |  Backlog grooming         @po               Tasks, acceptance criteria |
  +------------------------------------------------------------------------+
           |
           v
  +---------------------------------------------+
  | DELEGATION PROMPT FORMAT                     |
  | (from agent-communication skill)             |
  |                                              |
  |  1. Task: one-sentence description           |
  |  2. Context files: relevant paths only       |
  |  3. Deliverable: artifact + location         |
  |  4. Constraints: rules, boundaries           |
  |  5. Acceptance criteria: definition of done  |
  +---------------------------------------------+
```

---

## 5. Post-Delegation Signal Handling

When a subagent returns, Telamon reads the status signal and acts accordingly.

```
  Subagent returns
       |
       v
  +---------------------------+
  | Read status signal        |
  +---------------------------+
       |
       +------+------+------+------+
       |      |      |      |      |
       v      v      v      v      |
  FINISHED  BLOCKED  NEEDS   PARTIAL
             |      _INPUT    |
             |       |        |
             v       v        v
  +--------+ +-----+ +------+ +------+
  | Review | |Resolv| |Answer| |Resume|
  | deliv- | |block-| |quest-| |with  |
  | erable | |er:   | |ion   | |fresh |
  |        | |ask   | |your- | |deleg-|
  | Verify | |user, | |self  | |ation |
  | commit | |add   | |or    | |incl. |
  |        | |info, | |esca- | |partial|
  | Report | |re-   | |late  | |output|
  | to user| |deleg-| |to    | |+ only|
  |        | |ate   | |user  | |remain|
  | Skill: | |      | |      | |ing   |
  | remem- | |      | |Re-   | |work  |
  | ber_   | |      | |deleg-| |      |
  | task   | |      | |ate   | |      |
  +--------+ +-----+ +------+ +------+
```

---

## 6. Mandatory Post-Work Gates

After any work that changes files — whether handled directly or returned from a subagent.

```
  Work complete (handled directly or returned from subagent)
       |
       v
  +---------------------------------------+
  | GATE 1: Commit check                  |
  |                                       |
  | git status → uncommitted changes?     |
  |   YES → git add <specific files>      |
  |          git diff --staged --stat     |
  |          git commit -m "..."          |
  |          (never git add -A or .)      |
  |   NO  → continue                     |
  +---------------------------------------+
       |
       v
  +---------------------------------------+
  | GATE 2: Test suite (code changes only)|
  |                                       |
  | Delegate `make test` to @tester       |
  | Do NOT trust developer's claim        |
  |                                       |
  |   PASS → continue                     |
  |   FAIL → delegate fix to @developer   |
  |           re-run @tester              |
  |           loop until clean            |
  +---------------------------------------+
       |
       v
  +---------------------------------------+
  | GATE 3: Remember lessons              |
  |                                       |
  | Load remember_lessons_learned skill   |
  | Save decisions, patterns, bugs        |
  | to brain/ notes                       |
  |                                       |
  | If gotcha encountered:                |
  |   Load remember_gotcha skill          |
  |   Write to brain/gotchas.md           |
  +---------------------------------------+
       |
       v
  Report to human stakeholder
```

---

## 7. Routing Decision Tree

The complete if/else routing flowchart from request to action.

```
  User Request
       |
       v
  Is it a QUESTION? ──YES──> Handle directly (read, search, answer)
       |
      NO
       |
  Is it DOCUMENTATION? ──YES──> Handle directly
       |                         (gate: documentation_rules skill)
      NO
       |
  Is it META work? ──YES──> Handle directly
       |                     (gate: optimize-instructions if editing agents)
      NO
       |
  Is it a CODE FIX?
       |
      YES
       |
       +── Size SMALL? ──YES──> Delegate via implement_story skill
       |                         (Tester -> Developer -> Reviewer cycle)
       |
       +── Size MEDIUM+? ──YES──> Handle planning directly,
       |                           then delegate implementation
      NO
       |
  Is it TESTING? ──YES──> Delegate to @tester
       |
      NO
       |
  Is it REVIEW? ──YES──> Delegate to @reviewer
       |
      NO
       |
  Is it ARCHITECTURE? ──YES──> Delegate to @architect
       |
      NO
       |
  Is it DESIGN (UX)? ──YES──> Delegate to @ux-designer
       |
  Is it DESIGN (UI)? ──YES──> Delegate to @ui-designer
       |
      NO
       |
  Is it an AUDIT? ──YES──> Delegate to @critic
       |
      NO
       |
  Is it SECURITY? ──YES──> Delegate to @security
       |
      NO
       |
   Is it a STORY?
       |
      YES ──> Lead plan_story + implement_story directly
       |       Step 1: @po produces backlog (tasks, acceptance criteria)
       |       Step 2: @architect produces plan (PLAN.md)
       |       Step 3: @critic reviews plan (zero BLOCKERs required)
       |       Step 4: Optionally @ux-designer / @ui-designer specs
       |       Step 5: Implement via implement_story skill
       |               (@tester → @developer → @reviewer per task)
       |       Step 6: Retrospective + archive
       |
      NO
       |
  Is it an EPIC?
       |
      YES ──> Lead epic skill directly
       |       Step 1: @po breaks into stories
       |       Step 2: Plan each story (plan_story)
       |                Step 1: @po produces backlog (tasks, acceptance criteria)
       |                Step 2: @architect produces plan (PLAN.md)
       |                Step 3: @critic reviews plan (zero BLOCKERs required)
       |                Step 4: Optionally @ux-designer / @ui-designer specs
       |       Step 3: Epic-level @architect review
       |       Step 4: Implement each story (implement_story)
       |       Step 5: Retrospective + archive
       |
      NO
       |
  Is it a PRODUCT question? ──YES──> Delegate to @po
       |
      NO
       |
   ESCALATE to human stakeholder
```

---

## 8. Memory Capture & Compaction

These fire at specific moments during any workflow above — they are cross-cutting concerns.

```
  DURING WORK (any time):
        |
        +── Decision made, pattern spotted, or non-trivial bug fixed?
        |     YES ──> Skill: remember_lessons_learned
        |             Save to brain/ notes immediately (don't defer)
        |
        +── Hit a non-obvious trap, constraint, or recurring bug?
              YES ──> Skill: remember_gotcha
                      Write to brain/gotchas.md

  AFTER COMPLETING A TASK:
        |
        v
   +-------------------------------+
   | Skill: remember_task          |
   | Review discoveries, update    |
   | brain/memories.md with        |
   | structured lessons            |
   +-------------------------------+

  WHEN CONTEXT NEARS LIMIT (compaction):
        |
        | Triggers: opencode warns of compaction,
        |           responses slow down,
        |           context overflow imminent
        v
   +-------------------------------+
   | Skill: remember_checkpoint    |
   |                               |
   | Step 1: Persist working state |
   |         to brain/ notes       |
   | Step 2: Promote learnings     |
   |         from thinking/ drafts |
   | Step 3: Compact context       |
   | Step 4: Recall after          |
   |         compaction            |
   |         (recall_memories +    |
   |          recall_active_task)  |
   +-------------------------------+

  WHEN SESSION ENDS ("wrap up" / going idle):
        |
        v
   +-------------------------------+
   | Skill: remember_session       |
   |                               |
   | Step 1: Check watermark       |
   | Step 2: Identify what         |
   |         happened this session |
   | Step 3: Route to brain/ notes |
   | Step 4: Promote or discard    |
   |         thinking/ drafts      |
   | Step 5: Verify vault links    |
   | Step 6: Report what was saved |
   +-------------------------------+
```

---

## 9. Agents and Their Roles

```
  +---------------------------------------------------------------+
  |                     TELAMON (Orchestrator)                     |
  |  - Single entry point for all requests                        |
  |  - Classifies work (type + size)                              |
  |  - Routes to specialists or handles directly                  |
  |  - Leads planning and implementation workflows                |
  |  - Makes product decisions, approves/rejects                  |
  |  - MUST NOT: write production code, run tests, make arch      |
  |    decisions                                                  |
  +---------------------------------------------------------------+
       |
       | delegates to
       v
  +-------------------+  +-------------------+  +-------------------+
  | @po               |  | @architect        |  | @critic           |
  | Product Owner     |  | Software Arch.    |  | Critic            |
  |                   |  |                   |  |                   |
  | - Backlog/stories |  | - Technical plans |  | - Pattern drift   |
  | - Requirements    |  | - ADRs            |  | - Consistency     |
  | - Domain context  |  | - System design   |  | - Plan review     |
  | - Acceptance      |  | - File placement  |  | - Codebase audit  |
  |   criteria        |  |                   |  |                   |
  +-------------------+  +-------------------+  +-------------------+

  +-------------------+  +-------------------+  +-------------------+
  | @tester           |  | @developer        |  | @reviewer         |
  | Tester            |  | Developer         |  | Reviewer          |
  |                   |  |                   |  |                   |
  | - Write tests     |  | - Write code      |  | - Review changes  |
  | - Validate impl   |  | - Fix bugs        |  | - Check quality   |
  | - Run test suite  |  | - Address review  |  | - Verify plan     |
  | - Coverage check  |  |   findings        |  |   compliance      |
  |                   |  | - recall_gotchas  |  |                   |
  |                   |  |   at bootstrap    |  |                   |
  |                   |  | - remember_gotcha |  |                   |
  |                   |  |   when traps hit  |  |                   |
  +-------------------+  +-------------------+  +-------------------+

  +-------------------+  +-------------------+  +-------------------+
  | @ux-designer      |  | @ui-designer      |  | @security         |
  | UX Designer       |  | UI Designer       |  | Security Eng.     |
  |                   |  |                   |  |                   |
  | - User flows      |  | - Visual specs    |  | - Threat models   |
  | - Interaction     |  | - Design tokens   |  | - Vuln assessment |
  |   specs           |  | - Look & feel     |  | - Auth review     |
  | - States & rules  |  | - Hierarchy       |  | - Code audit      |
  +-------------------+  +-------------------+  +-------------------+
```

---

## 10. Communication Protocol

```
  Delegation:                    Status signals:
  +-------------------------+    +---------------------------+
  | 1. Task (one sentence)  |    | FINISHED!                 |
  | 2. Context files        |    | BLOCKED: <reason>         |
  | 3. Deliverable          |    | NEEDS_INPUT: <question>   |
  | 4. Constraints          |    | PARTIAL: <done + remains> |
  | 5. Acceptance criteria  |    +---------------------------+
  +-------------------------+

  Exception handling (loaded on failure):
  +-------+--------------------+---------------------------+
  | Code  | Type               | Recovery                  |
  +-------+--------------------+---------------------------+
  | E1    | Stalled session    | PARTIAL, re-delegate      |
  | E2    | Conflicting instr. | BLOCKED, escalate         |
  | E3    | Tool failure       | Retry, then BLOCKED       |
  | E4    | Test loop (3+ its) | Stop, fresh analysis      |
  | E5    | Context overflow   | PARTIAL, summarize        |
  | E6    | Scope creep        | Stop, document follow-up  |
  | E7    | Missing precedent  | NEEDS_INPUT               |
  +-------+--------------------+---------------------------+
```

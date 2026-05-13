---
name: skill-creator
description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

High-level process:

- Decide what skill should do and roughly how
- Write draft
- Create test prompts, run claude-with-access-to-skill on them
- Help user evaluate results qualitatively and quantitatively
  - While runs happen in background, draft quantitative evals if none exist (or modify existing). Explain them to user.
  - Use `eval-viewer/generate_review.py` script to show results for user review, plus quantitative metrics
- Rewrite skill based on feedback (and glaring flaws from quantitative benchmarks)
- Repeat until satisfied
- Expand test set, try again at larger scale

Your job: figure out where user is in this process, jump in, help progress through stages. Maybe user says "I want skill for X". Help narrow intent, write draft, write test cases, figure out evaluation approach, run prompts, repeat.

Maybe user already has draft — go straight to eval/iterate.

Always be flexible. If user says "don't need evaluations, just vibe", do that.

After skill done (order flexible), run description improver (separate script) to optimize triggering.

## Communicating with user

Skill creator used by people across wide range of familiarity with coding jargon. If you haven't heard, trend where Claude's power inspires plumbers to open terminals, parents to google "how to install npm". Bulk of users fairly computer-literate.

Pay attention to context cues for phrasing! Default guidelines:

- "evaluation" and "benchmark" borderline but OK
- "JSON" and "assertion" — need serious cues user knows these before using without explanation

OK to briefly explain terms if unsure, feel free to clarify with short definition.

---

## Creating a skill

### Capture Intent

Start by understanding user's intent. Current conversation might already contain workflow user wants to capture (e.g., "turn this into a skill"). If so, extract answers from conversation history first — tools used, sequence of steps, corrections user made, input/output formats observed. User may need to fill gaps, and should confirm before proceeding.

1. What should this skill enable Claude to do?
2. When should this skill trigger? (what user phrases/contexts)
3. What's expected output format?
4. Should we set up test cases? Skills with objectively verifiable outputs (file transforms, data extraction, code generation, fixed workflow steps) benefit from test cases. Skills with subjective outputs (writing style, art) often don't need them. Suggest appropriate default based on skill type, but let user decide.

### Interview and Research

Proactively ask about edge cases, input/output formats, example files, success criteria, dependencies. Wait to write test prompts until this part ironed out.

Check available MCPs — if useful for research (searching docs, finding similar skills, looking up best practices), research in parallel via subagents if available, otherwise inline. Come prepared with context to reduce burden on user.

### Write the SKILL.md

Based on user interview, fill in these components:

- **name**: Skill identifier
- **description**: When to trigger, what it does. Primary triggering mechanism — include both what skill does AND specific contexts for when to use. All "when to use" info goes here, not in body. Note: Claude tends to "undertrigger" skills. To combat this, make descriptions a bit "pushy". Instead of "How to build simple fast dashboard to display internal Anthropic data.", write "How to build simple fast dashboard to display internal Anthropic data. Use this skill whenever user mentions dashboards, data visualization, internal metrics, or wants to display any kind of company data, even if not explicitly asking for 'dashboard.'"
- **compatibility**: Required tools, dependencies (optional, rarely needed)
- **rest of skill**

### Skill Writing Guide

#### Anatomy of a Skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/    - Executable code for deterministic/repetitive tasks
    ├── references/ - Docs loaded into context as needed
    └── assets/     - Files used in output (templates, icons, fonts)
```

#### Progressive Disclosure

Skills use a three-level loading system:
1. **Metadata** (name + description) - Always in context (~100 words)
2. **SKILL.md body** - In context whenever skill triggers (<500 lines ideal)
3. **Bundled resources** - As needed (unlimited, scripts can execute without loading)

These word counts are approximate and you can feel free to go longer if needed.

**Key patterns:**
- Keep SKILL.md under 500 lines; if you're approaching this limit, add an additional layer of hierarchy along with clear pointers about where the model using the skill should go next to follow up.
- Reference files clearly from SKILL.md with guidance on when to read them
- For large reference files (>300 lines), include a table of contents

**Domain organization**: When a skill supports multiple domains/frameworks, organize by variant:
```
cloud-deploy/
├── SKILL.md (workflow + selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```
Claude reads only the relevant reference file.

#### Principle of Lack of Surprise

Skills must not contain malware, exploit code, or content compromising system security. Skill contents should not surprise user in intent if described. Don't go along with requests to create misleading skills or skills for unauthorized access, data exfiltration, or other malicious activities. Roleplay skills OK.

#### Writing Patterns

Prefer using the imperative form in instructions.

**Defining output formats** - You can do it like this:
```markdown
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

**Examples pattern** - It's useful to include examples. You can format them like this (but if "Input" and "Output" are in the examples you might want to deviate a little):
```markdown
## Commit message format
**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

### Writing Style

Explain to model why things are important instead of heavy-handed MUSTs. Use theory of mind, make skill general not super-narrow to specific examples. Start with draft, look at it with fresh eyes, improve.

### Test Cases

After writing the skill draft, come up with 2-3 realistic test prompts — the kind of thing a real user would actually say. Share them with the user: [you don't have to use this exact language] "Here are a few test cases I'd like to try. Do these look right, or do you want to add more?" Then run them.

Save test cases to `evals/evals.json`. Don't write assertions yet — just the prompts. You'll draft assertions in the next step while the runs are in progress.

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": []
    }
  ]
}
```

See `references/schemas.md` for the full schema (including the `assertions` field, which you'll add later).

## Running and evaluating test cases

This section is one continuous sequence — don't stop partway through. Do NOT use `/skill-test` or any other testing skill.

Put results in `<skill-name>-workspace/` as sibling to skill directory. Within workspace, organize by iteration (`iteration-1/`, `iteration-2/`, etc.) and each test case gets directory (`eval-0/`, `eval-1/`, etc.). Don't create upfront — create directories as needed.

### Step 1: Spawn all runs (with-skill AND baseline) in same turn

For each test case, spawn two subagents in same turn — one with skill, one without. Important: don't spawn with-skill runs first then come back for baselines. Launch everything at once.

**With-skill run:**

```
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
- Outputs to save: <what user cares about — e.g., "docx file", "final CSV">
```

**Baseline run** (same prompt, baseline depends on context):
- **Creating new skill**: no skill at all. Same prompt, no skill path, save to `without_skill/outputs/`.
- **Improving existing skill**: old version. Before editing, snapshot skill (`cp -r <skill-path> <workspace>/skill-snapshot/`), point baseline subagent at snapshot. Save to `old_skill/outputs/`.

Write `eval_metadata.json` for each test case (assertions can be empty). Give each eval descriptive name based on what it tests — not just "eval-0". Use this name for directory too. If iteration uses new or modified eval prompts, create files for each new eval directory — don't assume they carry over from previous iterations.

```json
{
  "eval_id": 0,
  "eval_name": "descriptive-name-here",
  "prompt": "The user's task prompt",
  "assertions": []
}
```

### Step 2: While runs in progress, draft assertions

Don't just wait for runs to finish — use this time productively. Draft quantitative assertions for each test case and explain them to user. If assertions already exist in `evals/evals.json`, review and explain what they check.

Good assertions objectively verifiable with descriptive names — read clearly in benchmark viewer so someone glancing at results understands what each checks. Subjective skills (writing style, design quality) better evaluated qualitatively — don't force assertions on things needing human judgment.

Update `eval_metadata.json` files and `evals/evals.json` with assertions once drafted. Explain what user will see in viewer — both qualitative outputs and quantitative benchmark.

### Step 3: As runs complete, capture timing data

When each subagent task completes, notification contains `total_tokens` and `duration_ms`. Save this data immediately to `timing.json` in run directory:

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332,
  "total_duration_seconds": 23.3
}
```

This is only opportunity to capture this data — comes through task notification, not persisted elsewhere. Process each notification as it arrives rather than batching.

### Step 4: Grade, aggregate, launch viewer

Once all runs done:

1. **Grade each run** — spawn grader subagent (or grade inline) reading `agents/grader.md` evaluating each assertion against outputs. Save to `grading.json` in each run directory. `grading.json` expectations array must use fields `text`, `passed`, `evidence` (not `name`/`met`/`details`) — viewer depends on exact field names. For assertions checkable programmatically, write and run script rather than eyeballing — scripts faster, more reliable, reusable across iterations.

2. **Aggregate into benchmark** — run aggregation script from skill-creator directory:
   ```bash
   python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
   ```
   Produces `benchmark.json` and `benchmark.md` with pass_rate, time, tokens for each configuration, mean ± stddev and delta. If generating benchmark.json manually, see `references/schemas.md` for exact schema viewer expects.
Put each with_skill version before its baseline counterpart.

3. **Analyst pass** — read benchmark data, surface patterns aggregate stats might hide. See `agents/analyzer.md` ("Analyzing Benchmark Results" section) for what to look for — assertions always pass regardless of skill (non-discriminating), high-variance evals (possibly flaky), time/token tradeoffs.

4. **Launch viewer** with both qualitative outputs and quantitative data:
   ```bash
   nohup python <skill-creator-path>/eval-viewer/generate_review.py \
     <workspace>/iteration-N \
     --skill-name "my-skill" \
     --benchmark <workspace>/iteration-N/benchmark.json \
     > /dev/null 2>&1 &
   VIEWER_PID=$!
   ```
   For iteration 2+, also pass `--previous-workspace <workspace>/iteration-<N-1>`.

   **Cowork / headless environments:** If `webbrowser.open()` not available or no display, use `--static <output_path>` to write standalone HTML file. Feedback downloads as `feedback.json` when user clicks "Submit All Reviews". After download, copy `feedback.json` into workspace directory for next iteration.

Note: use `generate_review.py` to create viewer; no need for custom HTML.

5. **Tell user**: "Opened results in browser. Two tabs — 'Outputs' lets you click through each test case and leave feedback, 'Benchmark' shows quantitative comparison. When done, come back and let me know."

### What the user sees in the viewer

"Outputs" tab shows one test case at a time:
- **Prompt**: task given
- **Output**: files skill produced, rendered inline where possible
- **Previous Output** (iteration 2+): collapsed section showing last iteration's output
- **Formal Grades** (if grading run): collapsed section showing assertion pass/fail
- **Feedback**: textbox auto-saving as they type
- **Previous Feedback** (iteration 2+): comments from last time, shown below textbox

"Benchmark" tab shows stats summary: pass rates, timing, token usage per configuration, with per-eval breakdowns and analyst observations.

Navigation via prev/next buttons or arrow keys. When done, click "Submit All Reviews" which saves feedback to `feedback.json`.

### Step 5: Read feedback

When user says done, read `feedback.json`:

```json
{
  "reviews": [
    {"run_id": "eval-0-with_skill", "feedback": "chart missing axis labels", "timestamp": "..."},
    {"run_id": "eval-1-with_skill", "feedback": "", "timestamp": "..."},
    {"run_id": "eval-2-with_skill", "feedback": "perfect, love this", "timestamp": "..."}
  ],
  "status": "complete"
}
```

Empty feedback means user thought it was fine. Focus improvements on test cases where user had specific complaints.

Kill viewer server when done:

```bash
kill $VIEWER_PID 2>/dev/null
```

---

## Improving skill

Heart of loop. Ran test cases, user reviewed results, now make skill better based on feedback.

### How to think about improvements

1. **Generalize from feedback.** Big picture: creating skills usable a million times (maybe literally) across many prompts. Here you and user iterate on few examples repeatedly because it moves faster. User knows these examples in and out, quick to assess new outputs. But if skill only works for those examples, useless. Rather than overfitty changes or oppressive MUSTs, try branching out with different metaphors, recommending different working patterns. Cheap to try, might land on something great.

2. **Keep prompt lean.** Remove things not pulling weight. Read transcripts, not just final outputs — if skill makes model waste time on unproductive things, remove those parts and see what happens.

3. **Explain the why.** Explain **why** behind everything asking model to do. LLMs are *smart*. Good theory of mind, given good harness can go beyond rote instructions. Even if user feedback terse or frustrated, understand task and why user wrote what they wrote, transmit understanding into instructions. If writing ALWAYS or NEVER in all caps, or super rigid structures — yellow flag. Reframe, explain reasoning so model understands why thing important. More humane, powerful, effective.

4. **Look for repeated work across test cases.** Read transcripts, notice if subagents all independently wrote similar helper scripts or took same multi-step approach. If all 3 test cases resulted in subagent writing `create_docx.py` or `build_chart.py`, strong signal skill should bundle that script. Write once, put in `scripts/`, tell skill to use it. Saves every future invocation from reinventing wheel.

This task important (creating billions in economic value here!). Thinking time not blocker; take time, really mull things over. Write draft revision, look at it anew, improve. Get into user's head, understand what they want and need.

### Iteration loop

After improving skill:

1. Apply improvements to skill
2. Rerun all test cases into new `iteration-<N+1>/` directory, including baseline runs. If creating new skill, baseline always `without_skill` (no skill) — stays same across iterations. If improving existing skill, use judgment on baseline: original version user came in with, or previous iteration.
3. Launch viewer with `--previous-workspace` pointing at previous iteration
4. Wait for user to review and tell you done
5. Read new feedback, improve again, repeat

Keep going until:
- User says happy
- Feedback all empty (everything looks good)
- Not making meaningful progress

---

## Advanced: Blind comparison

For rigorous comparison between two skill versions (e.g., user asks "is new version actually better?"), blind comparison system exists. Read `agents/comparator.md` and `agents/analyzer.md` for details. Basic idea: give two outputs to independent agent without telling which is which, let it judge quality. Then analyze why winner won.

Optional, requires subagents, most users won't need it. Human review loop usually sufficient.

---

## Description Optimization

The description field in SKILL.md frontmatter is the primary mechanism that determines whether Claude invokes a skill. After creating or improving a skill, offer to optimize the description for better triggering accuracy.

### Step 1: Generate trigger eval queries

Create 20 eval queries — mix of should-trigger and should-not-trigger. Save as JSON:

```json
[
  {"query": "user prompt", "should_trigger": true},
  {"query": "another prompt", "should_trigger": false}
]
```

Queries must be realistic — what Claude Code or Claude.ai user would actually type. Not abstract requests, but concrete, specific, detailed. File paths, personal context about user's job or situation, column names and values, company names, URLs. Backstory. Some lowercase, abbreviations, typos, casual speech. Mix lengths. Focus on edge cases rather than clear-cut (user will sign off).

Bad: `"Format this data"`, `"Extract text from PDF"`, `"Create a chart"`

Good: `"ok so my boss just sent me this xlsx file (its in my downloads, called something like 'Q4 sales final FINAL v2.xlsx') and she wants me to add a column that shows the profit margin as a percentage. Revenue in column C, costs in column D i think"`

For **should-trigger** queries (8-10): cover different phrasings of same intent — formal and casual. Include cases where user doesn't explicitly name skill or file type but clearly needs it. Throw in uncommon use cases and cases where skill competes with another but should win.

For **should-not-trigger** queries (8-10): most valuable are near-misses — queries sharing keywords or concepts but needing something different. Adjacent domains, ambiguous phrasing where naive keyword match would trigger but shouldn't, queries touching something skill does but in context where another tool more appropriate.

Key: don't make should-not-trigger queries obviously irrelevant. "Write fibonacci function" as negative test for PDF skill too easy — doesn't test anything. Negative cases genuinely tricky.

### Step 2: Review with user

Present eval set to user for review using HTML template:

1. Read template from `assets/eval_review.html`
2. Replace placeholders:
   - `__EVAL_DATA_PLACEHOLDER__` → JSON array of eval items (no quotes — JS variable assignment)
   - `__SKILL_NAME_PLACEHOLDER__` → skill name
   - `__SKILL_DESCRIPTION_PLACEHOLDER__` → skill's current description
3. Write to temp file (e.g., `/tmp/eval_review_<skill-name>.html`) and open: `open /tmp/eval_review_<skill-name>.html`
4. User can edit queries, toggle should-trigger, add/remove entries, click "Export Eval Set"
5. Downloads to `~/Downloads/eval_set.json` — check Downloads folder for most recent version if multiple (e.g., `eval_set (1).json`)

This step matters — bad eval queries lead to bad descriptions.

### Step 3: Run optimization loop

Tell user: "This takes time — I'll run optimization loop in background and check periodically."

Save eval set to workspace, run in background:

```bash
python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id-powering-this-session> \
  --max-iterations 5 \
  --verbose
```

Use model ID from system prompt (powering current session) so triggering test matches what user experiences.

While running, periodically tail output to give user updates on iteration and scores.

Handles full optimization loop automatically. Splits eval set into 60% train, 40% held-out test, evaluates current description (running each query 3 times for reliable trigger rate), calls Claude to propose improvements based on failures. Re-evaluates each new description on both train and test, iterating up to 5 times. When done, opens HTML report in browser with results per iteration and returns JSON with `best_description` — selected by test score rather than train score to avoid overfitting.

### How skill triggering works

Skills appear in Claude's `available_skills` list with name + description. Claude decides whether to consult skill based on description. Important: Claude only consults skills for tasks it can't easily handle alone — simple one-step queries like "read this PDF" may not trigger even if description matches perfectly, because Claude handles them directly with basic tools. Complex, multi-step, or specialized queries reliably trigger skills when description matches.

This means eval queries should be substantive enough that Claude would actually benefit from consulting a skill. Simple queries like "read file X" are poor test cases — won't trigger regardless of description quality.

### Step 4: Apply result

Take `best_description` from JSON output and update skill's SKILL.md frontmatter. Show user before/after and report scores.

---

### Package and Present (only if `present_files` tool available)

Check whether `present_files` tool accessible. If not, skip. If yes, package skill and present `.skill` file to user:

```bash
python -m scripts.package_skill <path/to/skill-folder>
```

After packaging, direct user to resulting `.skill` file path so they can install.

---

## Claude.ai-specific instructions

In Claude.ai, core workflow same (draft → test → review → improve → repeat), but Claude.ai lacks subagents so some mechanics change:

**Running test cases**: No subagents = no parallel execution. For each test case, read skill's SKILL.md, follow instructions to accomplish test prompt. One at a time. Less rigorous than independent subagents (you wrote skill and run it — full context), but useful sanity check — human review compensates. Skip baseline runs — just use skill to complete task.

**Reviewing results**: If can't open browser (Claude.ai VM no display or remote server), skip browser reviewer. Present results directly in conversation. For each test case, show prompt and output. If output is file user needs to see (.docx, .xlsx), save to filesystem, tell them where to download and inspect. Ask feedback inline: "How does this look? Anything change?"

**Benchmarking**: Skip quantitative benchmarking — relies on baseline comparisons not meaningful without subagents. Focus on qualitative feedback.

**Iteration loop**: Same — improve skill, rerun test cases, ask feedback — just without browser reviewer in middle. Still organize results into iteration directories on filesystem if available.

**Description optimization**: Requires `claude` CLI tool (`claude -p`) only available in Claude Code. Skip on Claude.ai.

**Blind comparison**: Requires subagents. Skip.

**Packaging**: `package_skill.py` works anywhere with Python and filesystem. On Claude.ai, run it, user downloads resulting `.skill` file.

**Updating existing skill**: User may ask to update existing skill, not create new one. In this case:
- **Preserve original name.** Note skill's directory name and `name` frontmatter field — use unchanged. E.g., if installed skill `research-helper`, output `research-helper.skill` (not `research-helper-v2`).
- **Copy to writeable location before editing.** Installed skill path may be read-only. Copy to `/tmp/skill-name/`, edit there, package from copy.
- **If packaging manually, stage in `/tmp/` first**, then copy to output directory — direct writes may fail due to permissions.

---

## Cowork-Specific Instructions

In Cowork, main things:

- Have subagents, so main workflow (spawn test cases in parallel, run baselines, grade, etc.) all works. (If severe timeout problems, OK to run test prompts in series.)
- No browser or display. When generating eval viewer, use `--static <output_path>` to write standalone HTML file. Proffer link user can click to open in their browser.
- Cowork setup seems to disincline Claude from generating eval viewer after running tests. Reiterate: whether Cowork or Claude Code, after running tests always generate eval viewer for human to look at examples before revising skill, using `generate_review.py` (not custom HTML). GENERATE EVAL VIEWER *BEFORE* evaluating inputs yourself. Get results in front of human ASAP!
- Feedback works differently: no running server, viewer's "Submit All Reviews" button downloads `feedback.json` as file. Read from there (may need to request access first).
- Packaging works — `package_skill.py` just needs Python and filesystem.
- Description optimization (`run_loop.py` / `run_eval.py`) should work in Cowork since uses `claude -p` via subprocess, not browser. Save until fully finished making skill and user agrees it's in good shape.
- **Updating existing skill**: User may ask to update existing skill. Follow update guidance in Claude.ai section above.

---

## Reference files

`agents/` directory contains instructions for specialized subagents. Read when spawning relevant subagent.

- `agents/grader.md` — Evaluate assertions against outputs
- `agents/comparator.md` — Blind A/B comparison between outputs
- `agents/analyzer.md` — Analyze why one version beat another

`references/` directory has additional docs:
- `references/schemas.md` — JSON structures for evals.json, grading.json, etc.

---

Core loop again:

- Figure out what skill is about
- Draft or edit skill
- Run claude-with-access-to-skill on test prompts
- With user, evaluate outputs:
  - Create benchmark.json, run `eval-viewer/generate_review.py` for user review
  - Run quantitative evals
- Repeat until satisfied
- Package final skill, return to user.

Add steps to TodoList to not forget. In Cowork, specifically put "Create evals JSON and run `eval-viewer/generate_review.py` so human can review test cases" in TodoList.

Good luck!

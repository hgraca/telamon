---
description: Build a patched opencode binary from .telamon.jsonc::opencode_patches and install it (with backup)
agent: telamon/telamon
---

You are running `/patch-opencode` workflow. Keep script moving forward — including resolving merge conflicts — until patched binary installed (or, with `--dry-run`, validated) or unrecoverable failure hit.

This is **loop**, not single command invocation. Likely run script multiple times (initial run + one `--resume` per conflicting PR).

## Arguments

`$ARGUMENTS` forwarded verbatim to script. Supported forms:

- `<base-ref>` — what to patch on top of:
  - omitted or `latest` → latest released opencode tag (default)
  - `dev` → upstream `dev` branch HEAD
  - `<version>` (e.g. `1.14.44` or `v1.14.44`) → that specific release tag
- `--dry-run` — build & smoke-test only; do **not** back up or replace `~/.opencode/bin/opencode`. Conflict resolution still happens — `--dry-run` only changes final install step.
- `--resume` — continue after resolving merge conflicts in working tree. Script adds this when looping; you rarely pass manually.

Flags and base-ref can combine in any order, e.g. `/patch-opencode dev --dry-run`.

Patched binary always stamped as version `666.0.0` so user can tell at glance (`opencode --version`) they run patched build. Telamon updater (`make update`) detects this stamp and skips npm so it never clobbers patched build.

## Workflow

1. **Run script** with user's args:
   `bash .opencode/commands/telamon/patch-opencode/patch-opencode.sh $ARGUMENTS`
2. **Inspect exit code** and act per table below.
3. On exit 3 (conflict): resolve and re-invoke with `--resume`. Repeat until exit 0, exit 2, exit 1, or 3 re-invokes **in a row without progress** (same `conflict_pr`, same `conflicting_files`).
4. **Report final outcome** to user with: installed version (or "dry-run only"), applied PRs, skipped PRs, and abandoned PRs.

## Exit codes

| Code | Meaning               | What you do                                                                    |
|------|-----------------------|--------------------------------------------------------------------------------|
| 0    | Success               | Report installed version + summary (applied PRs, skipped PRs) to user. Done.   |
| 2    | No patches configured | Tell user `opencode_patches` empty in `.telamon.jsonc`. Done.                  |
| 3    | Merge conflict        | **Resolve and resume — do NOT stop here.** See conflict-resolution loop below. |
| 1    | Fatal error           | Read error, diagnose, report to user. Do not retry blindly.                    |

## Conflict resolution loop (exit 3 → resolve → resume)

Script has written `storage/opencode-patch-conflict.json` with:
- `conflict_pr` — PR URL whose patch caused conflict
- `target_ref` — base ref being patched
- `src_dir` — absolute path to opencode source clone
- `conflicting_files` — files with `<<<<<<< / ======= / >>>>>>>` markers
- `applied_prs` / `skipped_prs` — what already happened

For each exit-3 cycle:

1. **Read conflict JSON**:
   `cat storage/opencode-patch-conflict.json`
2. **Inspect conflicting PR** to understand intent. Extract PR number from `conflict_pr` and run:
   `gh pr view <pr-number> --repo anomalyco/opencode --json title,body`
   `gh pr diff <pr-number> --repo anomalyco/opencode`
3. **For each file in `conflicting_files`**:
   - Read file (now contains `<<<<<<< / ======= / >>>>>>>` markers)
   - Resolve conflict — keep PR's intent on top of current `target_ref` code. Common patterns:
     - Same change made differently → keep one, drop other
     - Adjacent edits → keep both, ordered correctly
     - PR depends on code no longer existing → port PR's change to equivalent new location, OR abandon PR (see below)
   - Write resolved file (no markers left)
4. **Stage resolved files**:
   `git -C <src_dir> add <file1> <file2> ...`
5. **Verify no unresolved markers remain**:
   `git -C <src_dir> diff --check`
6. **Re-invoke script with `--resume`**, preserving original args:
   `bash .opencode/commands/telamon/patch-opencode/patch-opencode.sh --resume <original-args>`
7. **Loop** — next exit code drives next action. Script may surface another conflict for next PR; treat same way.

### Abandoning hopeless PR

If PR clearly unsalvageable (months-stale, target code rewritten or removed, conflict intractable), abandon it for this run:

1. Tell user **which PR abandoned and why** (one-paragraph diagnosis citing specific conflict).
2. Reset working tree to drop failed patch:
   `git -C <src_dir> reset --hard <target_ref>`
3. **Temporarily** comment-out PR in `.telamon.jsonc::opencode_patches` (do not delete — leave `// TODO: stale, see <date>` note).
4. Re-run script from scratch (no `--resume`) so it picks up shorter list:
   `bash .opencode/commands/telamon/patch-opencode/patch-opencode.sh <original-args>`
5. After run completes, **restore** user's original `.telamon.jsonc` (uncomment PR, possibly with follow-up comment) and tell them situation so they can decide whether to drop permanently.

Never silently drop PR. Never delete PR URL from config without telling user.

### Stop conditions for loop

Stop loop and report to user when **any** of:
- Script exits 0 → success.
- Script exits 1 → fatal error (build failed, smoke test failed, etc.). Report error.
- 3 re-invokes of `--resume` for same `conflict_pr` without progress → call stall, abandon that PR per procedure above and continue, OR ask user if unsure.
- User interrupts.

## State files

- `storage/opencode-src/` — opencode source clone (kept between runs for fast incremental fetches)
- `storage/opencode-src/combined.patch` — diff of all applied PRs vs. `target_ref` (record only)
- `storage/opencode-backups/` — previous binaries, named `opencode-v<version>-<timestamp>`
- `storage/opencode-patch-state.json` — last successful patch state (real install only, not dry-run)
- `storage/opencode-patch-conflict.json` — present only while conflict being resolved
---
description: Build a patched opencode binary from .telamon.jsonc::opencode_patches and install it (with backup)
agent: telamon/telamon
---

You are running the `/patch-opencode` workflow. Your job is to keep the script moving forward — including resolving any merge conflicts it surfaces — until either the patched binary is installed (or, with `--dry-run`, validated) or you hit an unrecoverable failure.

This is a **loop**, not a single command invocation. You will likely run the script multiple times (initial run + one `--resume` per conflicting PR).

## Arguments

`$ARGUMENTS` is forwarded verbatim to the script. Supported forms:

- `<base-ref>` — what to patch on top of:
  - omitted or `latest` → the latest released opencode tag (default)
  - `dev` → the upstream `dev` branch HEAD
  - `<version>` (e.g. `1.14.44` or `v1.14.44`) → that specific release tag
- `--dry-run` — build & smoke-test only; do **not** back up or replace `~/.opencode/bin/opencode`. Conflict resolution still happens — `--dry-run` only changes the final install step.
- `--resume` — continue after you have resolved merge conflicts in the working tree. The script adds this for you when looping; you rarely pass it manually.

Flags and the base-ref can be combined in any order, e.g. `/patch-opencode dev --dry-run`.

The patched binary is always stamped as version `666.0.0` so the user can tell at a glance (`opencode --version`) that they are running the patched build. The Telamon updater (`make update`) detects this stamp and skips npm so it never clobbers a patched build.

## Workflow

1. **Run the script** with the user's args:
   `bash .opencode/commands/telamon/patch-opencode/patch-opencode.sh $ARGUMENTS`
2. **Inspect the exit code** and act per the table below.
3. On exit 3 (conflict): resolve and re-invoke with `--resume`. Repeat until exit 0, exit 2, exit 1, or you have re-invoked **3 times in a row without progress** (same `conflict_pr`, same `conflicting_files`).
4. **Report the final outcome** to the user with: installed version (or "dry-run only"), applied PRs, skipped PRs, and any PRs you abandoned.

## Exit codes

| Code | Meaning                | What you do                                                                                  |
|------|------------------------|----------------------------------------------------------------------------------------------|
| 0    | Success                | Report installed version + summary (applied PRs, skipped PRs) to the user. Done.             |
| 2    | No patches configured  | Tell the user `opencode_patches` is empty in `.telamon.jsonc`. Done.                         |
| 3    | Merge conflict         | **Resolve and resume — do NOT stop here.** See the conflict-resolution loop below.           |
| 1    | Fatal error            | Read the error, diagnose, report to the user. Do not retry blindly.                          |

## Conflict resolution loop (exit 3 → resolve → resume)

The script has written `storage/opencode-patch-conflict.json` with:
- `conflict_pr` — the PR URL whose patch caused the conflict
- `target_ref` — the base ref being patched
- `src_dir` — absolute path to the opencode source clone
- `conflicting_files` — list of files with `<<<<<<< / ======= / >>>>>>>` markers
- `applied_prs` / `skipped_prs` — what already happened

For each exit-3 cycle:

1. **Read the conflict JSON**:
   `cat storage/opencode-patch-conflict.json`
2. **Inspect the conflicting PR** to understand intent. Extract the PR number from `conflict_pr` and run:
   `gh pr view <pr-number> --repo anomalyco/opencode --json title,body`
   `gh pr diff <pr-number> --repo anomalyco/opencode`
3. **For each file in `conflicting_files`**:
   - Read the file (it now contains `<<<<<<< / ======= / >>>>>>>` markers)
   - Resolve the conflict — keep the PR's intent on top of the current `target_ref` code. Common patterns:
     - Same change made differently → keep one, drop the other
     - Adjacent edits → keep both, ordered correctly
     - PR depends on code that no longer exists → port the PR's change to the equivalent new location, OR abandon the PR (see below)
   - Write the resolved file (no markers left)
4. **Stage the resolved files**:
   `git -C <src_dir> add <file1> <file2> ...`
5. **Verify no unresolved markers remain**:
   `git -C <src_dir> diff --check`
6. **Re-invoke the script with `--resume`**, preserving the original args:
   `bash .opencode/commands/telamon/patch-opencode/patch-opencode.sh --resume <original-args>`
7. **Loop** — the next exit code drives the next action. The script may surface another conflict for the next PR; treat it the same way.

### Abandoning a hopeless PR

If a PR is clearly unsalvageable (months-stale, target code rewritten or removed, conflict is intractable), you may abandon it for this run:

1. Tell the user **which PR you are abandoning and why** (one-paragraph diagnosis citing the specific conflict).
2. Reset the working tree to drop the failed patch:
   `git -C <src_dir> reset --hard <target_ref>`
3. **Temporarily** comment-out the PR in `.telamon.jsonc::opencode_patches` (do not delete — leave a `// TODO: stale, see <date>` note).
4. Re-run the script from scratch (no `--resume`) so it picks up the now-shorter list:
   `bash .opencode/commands/telamon/patch-opencode/patch-opencode.sh <original-args>`
5. After the run completes, **restore** the user's original `.telamon.jsonc` (uncomment the PR, possibly with a follow-up comment) and tell them the situation so they can decide whether to drop it permanently.

Never silently drop a PR. Never delete the PR URL from the config without telling the user.

### Stop conditions for the loop

Stop the loop and report to the user when **any** of:
- Script exits 0 → success.
- Script exits 1 → fatal error (build failed, smoke test failed, etc.). Report the error.
- You have re-invoked `--resume` 3 times for the same `conflict_pr` without progress → call this a stall, abandon that PR per the procedure above and continue, OR ask the user what to do if you are unsure.
- The user interrupts.

## State files

- `storage/opencode-src/` — opencode source clone (kept between runs for fast incremental fetches)
- `storage/opencode-src/combined.patch` — the diff of all applied PRs vs. `target_ref` (record only)
- `storage/opencode-backups/` — previous binaries, named `opencode-v<version>-<timestamp>`
- `storage/opencode-patch-state.json` — last successful patch state (real install only, not dry-run)
- `storage/opencode-patch-conflict.json` — present only while a conflict is being resolved

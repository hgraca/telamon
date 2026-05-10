---
description: Build a patched opencode binary from .telamon.jsonc::opencode_patches and install it (with backup)
agent: telamon/telamon
---

Run `.opencode/commands/telamon/patch-opencode/patch-opencode.sh $ARGUMENTS` and follow its output.

The script does everything autonomously — downloading PRs, applying them, building, smoke-testing, and swapping the installed binary with a backup. Your only job as the agent is to handle merge conflicts when the script asks for help.

## Arguments

`$ARGUMENTS` is forwarded verbatim. Supported forms:

- `<base-ref>` — what to patch on top of:
  - omitted or `latest` → the latest released opencode tag (default)
  - `dev` → the upstream `dev` branch HEAD
  - `<version>` (e.g. `1.14.44` or `v1.14.44`) → that specific release tag
- `--dry-run` — build & smoke-test only; do **not** back up or replace `~/.opencode/bin/opencode`. Use this to validate that patches still apply and the build is healthy without touching the live binary.
- `--resume` — continue after you have resolved merge conflicts in the working tree (see below).

Flags and the base-ref can be combined in any order, e.g. `/patch-opencode dev --dry-run` or `/patch-opencode --resume 1.14.44`.

The patched binary is always stamped as version `666.0.0` so the user can tell at a glance (`opencode --version`) that they are running the patched build. The Telamon updater (`make update`) detects this stamp and skips npm so it never clobbers a patched build.

## Exit codes

| Code | Meaning                | What you do                                                                                  |
|------|------------------------|----------------------------------------------------------------------------------------------|
| 0    | Success                | Report installed version + summary (applied PRs, skipped PRs) to the user.                   |
| 2    | No patches configured  | Tell the user `opencode_patches` is empty in `.telamon.jsonc`. Done.                         |
| 3    | Merge conflict         | **Resolve conflicts, then re-run with `--resume`** (see below).                              |
| 1    | Fatal error            | Read the error, diagnose, report to the user. Do not retry blindly.                          |

## Conflict resolution workflow (exit 3)

When the script exits 3, it has written `storage/opencode-patch-conflict.json` with:
- `conflict_pr` — the PR URL whose patch caused the conflict
- `target_ref` — the base ref being patched
- `src_dir` — absolute path to the opencode source clone
- `conflicting_files` — list of files with `<<<<<<< / ======= / >>>>>>>` markers
- `applied_prs` / `skipped_prs` — what already happened

Steps:

1. Read the conflict JSON: `cat storage/opencode-patch-conflict.json`
2. Read the conflicting PR's diff if helpful: `gh pr diff <pr-number> --repo anomalyco/opencode`
3. For each file in `conflicting_files`:
   - Read the file
   - Resolve the conflict markers (keep the right hunks; merge intent)
   - Write the resolved file back
4. Stage the resolved files: `cd <src_dir> && git add <file>...`
5. Re-run the script with `--resume`: `bash .opencode/commands/telamon/patch-opencode/patch-opencode.sh --resume <base-ref>`

The `--resume` flag tells the script to skip the patch-application phase (the working tree already has the resolved state) and jump straight to building, smoke-testing, and installing.

If a single PR is hopeless (e.g. it's months stale and the affected code has been rewritten), it is acceptable to:
- Document the situation to the user
- Suggest removing that PR URL from `.telamon.jsonc::opencode_patches`
- Ask the user how to proceed

Do not silently drop a PR — the user configured it for a reason.

## State files

- `storage/opencode-src/` — opencode source clone (kept between runs for fast incremental fetches)
- `storage/opencode-src/combined.patch` — the diff of all applied PRs vs. `target_ref` (record only)
- `storage/opencode-backups/` — previous binaries, named `opencode-v<version>-<timestamp>`
- `storage/opencode-patch-state.json` — last successful patch state
- `storage/opencode-patch-conflict.json` — present only while a conflict is being resolved

#!/usr/bin/env bash
# Pre-commit gate: runs `make test DRY_RUN=--dry-run` before allowing the
# commit to proceed. Called from git pre-commit hook.
#
# Usage: run-tests-hook-runner.sh <project-path>
#
# Trigger model:
# - Only fires when the commit was made from inside an opencode session
#   (i.e. $OPENCODE_SESSION_ID is set in the inherited environment).
# - The session-id-export.js plugin populates OPENCODE_SESSION_ID on every
#   tool.execute.before, so any bash tool invocation (including `git commit`)
#   inherits it.
# - Manual commits made from a normal terminal carry no OPENCODE_SESSION_ID
#   → this hook exits 0 silently. Intentional: we never want to block human
#   commits with this gate; it only guards opencode-driven commits so the
#   LLM sees test failures before claiming "done".
#
# Behaviour:
# - No `make` binary OR no `make test` target → skip with a short notice (exit 0)
# - `make test DRY_RUN=--dry-run` exits 0 → silent, commit proceeds
# - `make test DRY_RUN=--dry-run` exits non-zero → print captured output, abort commit (exit 1)
#
# Requirements:
# - $OPENCODE_SESSION_ID must be set (commit originated from an opencode session)

set -uo pipefail

PROJECT_PATH="${1:?run-tests-hook-runner.sh requires project path as \$1}"

# Resolve absolute path
PROJECT_PATH="$(cd "${PROJECT_PATH}" && pwd)" || exit 0

# Must have an originating opencode session — otherwise skip silently.
# Human commits from a normal terminal are not gated by this hook.
if [[ -z "${OPENCODE_SESSION_ID:-}" ]]; then
  exit 0
fi

cd "${PROJECT_PATH}" || exit 0

# `make` must be installed — otherwise skip with a short notice.
if ! command -v make >/dev/null 2>&1; then
  echo "[run-tests] make not installed — skipping pre-commit test gate" >&2
  exit 0
fi

# A Makefile must exist — otherwise skip with a short notice.
if [[ ! -f "Makefile" ]] && [[ ! -f "makefile" ]] && [[ ! -f "GNUmakefile" ]]; then
  echo "[run-tests] no Makefile in ${PROJECT_PATH} — skipping pre-commit test gate" >&2
  exit 0
fi

# A `test` target must exist — otherwise skip with a short notice.
# `make -n test` does a dry-run; non-zero means the target is missing.
if ! make -n test >/dev/null 2>&1; then
  echo "[run-tests] no \`make test\` target — skipping pre-commit test gate" >&2
  exit 0
fi

# Run the tests. Capture output so we can report it back on failure.
echo "[run-tests] running \`make test DRY_RUN=--dry-run\` before commit…" >&2

TEST_OUTPUT="$(mktemp)"
trap 'rm -f "${TEST_OUTPUT}"' EXIT

if make test DRY_RUN=--dry-run >"${TEST_OUTPUT}" 2>&1; then
  echo "[run-tests] make test passed — commit proceeding" >&2
  exit 0
fi

EXIT_CODE=$?

# Report failures back so the LLM can reason about them.
echo "" >&2
echo "[run-tests] ABORT: \`make test DRY_RUN=--dry-run\` failed (exit ${EXIT_CODE})" >&2
echo "[run-tests] --- output ---" >&2
cat "${TEST_OUTPUT}" >&2
echo "[run-tests] --- end output ---" >&2
echo "" >&2
echo "[run-tests] Commit aborted. Fix the failing tests, then retry." >&2

exit 1

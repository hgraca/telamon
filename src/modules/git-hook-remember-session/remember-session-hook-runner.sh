#!/usr/bin/env bash
# Background worker: runs telamon.remember_session for a project after commit.
# Called from git post-commit hook.
# Must be completely silent — no output to terminal.
#
# Usage: remember-session-hook-runner.sh <project-path>
#
# Trigger model:
# - Only fires when the commit was made from inside an opencode session
#   (i.e. $OPENCODE_SESSION_ID is set in the inherited environment).
# - The session-id-export.js plugin populates OPENCODE_SESSION_ID on every
#   tool.execute.before, so any bash tool invocation (including `git commit`)
#   inherits it.
# - Manual commits made from a normal terminal carry no OPENCODE_SESSION_ID
#   → this hook exits silently and produces no capture. This is intentional:
#   we never want to inject a capture prompt into an unrelated session via
#   --continue.
#
# Requirements:
# - opencode CLI must be installed
# - .ai/telamon directory must exist (project initialized)
# - $OPENCODE_SESSION_ID must be set (commit originated from an opencode session)

set -uo pipefail

PROJECT_PATH="${1:?remember-session-hook-runner.sh requires project path as \$1}"

# Resolve absolute path
PROJECT_PATH="$(cd "${PROJECT_PATH}" && pwd)" || exit 0

LOG_DIR="${PROJECT_PATH}/.ai/telamon"
PID_FILE="${LOG_DIR}/.remember-session-hook.pid"
LOG_FILE="${LOG_DIR}/.remember-session-hook.log"

# opencode must be installed
if ! command -v opencode >/dev/null 2>&1; then
  exit 0
fi

# .ai/telamon directory must exist (project initialized)
if [[ ! -d "${LOG_DIR}" ]]; then
  exit 0
fi

# Must have an originating opencode session — otherwise skip silently.
# (Commits from a normal terminal have no OPENCODE_SESSION_ID and we
# refuse to fall back to --continue, which would target an unrelated session.)
if [[ -z "${OPENCODE_SESSION_ID:-}" ]]; then
  exit 0
fi

SESSION_ID="${OPENCODE_SESSION_ID}"

# Collect the commit(s) that triggered this hook.
# post-commit always has HEAD; post-rewrite passes old/new pairs on stdin.
COMMIT_INFO="$(git -C "${PROJECT_PATH}" log -1 --oneline HEAD 2>/dev/null || true)"

# Kill any running remember-session process for this project
if [[ -f "${PID_FILE}" ]]; then
  OLD_PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${OLD_PID}" ]] && kill -0 "${OLD_PID}" 2>/dev/null; then
    OLD_CMD="$(ps -p "${OLD_PID}" -o command= 2>/dev/null || true)"
    if [[ "${OLD_CMD}" == *opencode* ]]; then
      kill "${OLD_PID}" 2>/dev/null || true
      sleep 0.2
    fi
  fi
  rm -f "${PID_FILE}"
fi

# Rotate log file if it exceeds ~100 KB
if [[ -f "${LOG_FILE}" ]] && [[ "$(wc -c < "${LOG_FILE}" 2>/dev/null || echo 0)" -gt 102400 ]]; then
  tail -n 50 "${LOG_FILE}" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "${LOG_FILE}" || true
fi

# Launch opencode run in background with nohup so it survives terminal close.
# Targets the originating session by ID — never falls back to --continue.
(
  echo "${BASHPID}" > "${PID_FILE}"

  cd "${PROJECT_PATH}" || exit 0
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] remember-session started (session=${SESSION_ID})" >> "${LOG_FILE}"

  nohup opencode run \
    --session "${SESSION_ID}" \
    --pure \
    "A git commit was just made. Run the telamon.remember_session skill to capture any session knowledge worth keeping. Be brief, silent, and only save genuinely new insights. Then continue with any leftover work to do, if any.

Commit that triggered this capture:
${COMMIT_INFO}" \
    >> "${LOG_FILE}" 2>&1

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] remember-session finished (exit $?)" >> "${LOG_FILE}"

  # Only remove PID file if it still contains our PID
  if [[ "$(cat "${PID_FILE}" 2>/dev/null || true)" == "${BASHPID}" ]]; then
    rm -f "${PID_FILE}"
  fi
) &

BGPID=$!

# Detach completely
disown "${BGPID}" 2>/dev/null || true

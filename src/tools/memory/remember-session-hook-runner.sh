#!/usr/bin/env bash
# Background worker: runs telamon.remember_session for a project after commit.
# Called from git post-commit hook.
# Must be completely silent — no output to terminal.
#
# Usage: remember-session-hook-runner.sh <project-path>
#
# Requirements:
# - opencode CLI must be installed
# - Only runs for the current project and session
# - Incremental: uses --continue to append to the current session

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
# Uses --continue to resume the current session (incremental).
(
  echo "${BASHPID}" > "${PID_FILE}"

  cd "${PROJECT_PATH}" || exit 0
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] remember-session started" >> "${LOG_FILE}"

  # Run the remember_session skill via opencode CLI
  # --continue resumes the last session (incremental, same session context)
  nohup opencode run \
    --continue \
    --pure \
    "A git commit was just made. Run the telamon.remember_session skill to capture any session knowledge worth keeping. Be brief and only save genuinely new insights." \
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

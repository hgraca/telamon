#!/usr/bin/env bash
# Background worker: runs graphify update for a project.
# Called from git hooks (post-checkout, post-commit).
# Must be completely silent — no output to terminal.
#
# Usage: graphify-hook-runner.sh <project-path>

# -e is intentionally omitted: the script uses `|| exit 0` patterns throughout,
# which would conflict with set -e (any failed subcommand would abort the script
# before the fallback could run).
set -uo pipefail

PROJECT_PATH="${1:?graphify-hook-runner.sh requires project path as \$1}"

# Resolve absolute path
PROJECT_PATH="$(cd "${PROJECT_PATH}" && pwd)" || exit 0

GRAPHIFY_OUT="${PROJECT_PATH}/graphify-out"
PID_FILE="${GRAPHIFY_OUT}/.graphify-hook.pid"
LOG_FILE="${GRAPHIFY_OUT}/.graphify-hook.log"

# graphify must be installed
if ! command -v graphify >/dev/null 2>&1; then
  exit 0
fi

# graphify-out must exist (symlinked during init)
if [[ ! -d "${GRAPHIFY_OUT}" ]]; then
  exit 0
fi

# Kill any running graphify process for this project
if [[ -f "${PID_FILE}" ]]; then
  OLD_PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${OLD_PID}" ]] && kill -0 "${OLD_PID}" 2>/dev/null; then
    # Verify the process is actually graphify-related before killing it.
    # After a reboot the PID may belong to a completely unrelated process.
    OLD_CMD="$(ps -p "${OLD_PID}" -o command= 2>/dev/null || true)"
    if [[ "${OLD_CMD}" == *graphify* ]]; then
      kill "${OLD_PID}" 2>/dev/null || true
      sleep 0.2
    fi
  fi
  rm -f "${PID_FILE}"
fi

# Rotate log file if it exceeds ~100 KB to prevent unbounded growth
if [[ -f "${LOG_FILE}" ]] && [[ "$(wc -c < "${LOG_FILE}" 2>/dev/null || echo 0)" -gt 102400 ]]; then
  tail -n 50 "${LOG_FILE}" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "${LOG_FILE}" || true
fi

# Launch graphify update in background.
# The subshell writes its own PID as its first action (fixes race condition:
# previously $! was written after backgrounding, but the subshell could finish
# and remove the PID file before the parent wrote it).
(
  # Write own PID immediately, before doing any work
  echo "${BASHPID}" > "${PID_FILE}"

  cd "${PROJECT_PATH}" || exit 0
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] graphify update started" >> "${LOG_FILE}"
  graphify update . >> "${LOG_FILE}" 2>&1
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] graphify update finished (exit $?)" >> "${LOG_FILE}"

  # Only remove PID file if it still contains our PID (guards against a newer
  # invocation having already replaced it)
  if [[ "$(cat "${PID_FILE}" 2>/dev/null || true)" == "${BASHPID}" ]]; then
    rm -f "${PID_FILE}"
  fi
) &

BGPID=$!

# Detach completely
disown "${BGPID}" 2>/dev/null || true

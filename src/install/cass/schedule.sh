#!/usr/bin/env bash
# Create or remove a scheduled job that runs cass incremental index
# every 30 minutes via platform-native timers (systemd on Linux, launchd on macOS).
#
# Usage:
#   schedule.sh                    — create timer
#   schedule.sh --remove           — remove timer
#
# Requires: no project-specific env vars (cass indexes globally)

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# ── Parse arguments ───────────────────────────────────────────────────────────
if [[ "${1:-}" == "--remove" ]]; then
  REMOVE_MODE=true
else
  REMOVE_MODE=false
fi

OS="$(uname -s)"
JOB_NAME="cass-index"

# ── Linux (systemd) ──────────────────────────────────────────────────────────
if [[ "${OS}" == "Linux" ]]; then
  UNIT_DIR="${HOME}/.config/systemd/user"
  SERVICE_FILE="${UNIT_DIR}/${JOB_NAME}.service"
  TIMER_FILE="${UNIT_DIR}/${JOB_NAME}.timer"

  if [[ "${REMOVE_MODE}" == "true" ]]; then
    systemctl --user disable --now "${JOB_NAME}.timer" 2>/dev/null || true
    rm -f "${SERVICE_FILE}" "${TIMER_FILE}"
    systemctl --user daemon-reload 2>/dev/null || true
    log "Removed scheduled job: ${JOB_NAME}"
    exit 0
  fi

  mkdir -p "${UNIT_DIR}"

  SERVICE_CONTENT="[Unit]
Description=cass incremental index

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cass index >/dev/null 2>&1'"

  TIMER_CONTENT="[Unit]
Description=cass index timer

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target"

  # Idempotency: skip if content is identical
  if [[ -f "${SERVICE_FILE}" && -f "${TIMER_FILE}" ]]; then
    EXISTING_SERVICE="$(cat "${SERVICE_FILE}")"
    EXISTING_TIMER="$(cat "${TIMER_FILE}")"
    if [[ "${EXISTING_SERVICE}" == "${SERVICE_CONTENT}" && "${EXISTING_TIMER}" == "${TIMER_CONTENT}" ]]; then
      skip "Scheduled job ${JOB_NAME} (already configured)"
      exit 0
    fi
  fi

  printf '%s' "${SERVICE_CONTENT}" > "${SERVICE_FILE}"
  printf '%s' "${TIMER_CONTENT}" > "${TIMER_FILE}"
  systemctl --user daemon-reload
  systemctl --user enable --now "${JOB_NAME}.timer"
  log "Scheduled job created: ${JOB_NAME} (every 30 min)"
  info "Manage with: systemctl --user status ${JOB_NAME}.timer"

# ── macOS (launchd) ──────────────────────────────────────────────────────────
elif [[ "${OS}" == "Darwin" ]]; then
  PLIST_DIR="${HOME}/Library/LaunchAgents"
  PLIST_FILE="${PLIST_DIR}/com.telamon.${JOB_NAME}.plist"

  if [[ "${REMOVE_MODE}" == "true" ]]; then
    launchctl bootout "gui/$(id -u)" "${PLIST_FILE}" 2>/dev/null || true
    rm -f "${PLIST_FILE}"
    log "Removed scheduled job: ${JOB_NAME}"
    exit 0
  fi

  mkdir -p "${PLIST_DIR}"

  PLIST_CONTENT='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.telamon.'"${JOB_NAME}"'</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>cass index &gt;/dev/null 2&gt;&amp;1</string>
  </array>
  <key>StartInterval</key>
  <integer>1800</integer>
  <key>StandardOutPath</key>
  <string>/tmp/'"${JOB_NAME}"'.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/'"${JOB_NAME}"'.err</string>
</dict>
</plist>'

  # Idempotency: skip if content is identical
  if [[ -f "${PLIST_FILE}" ]]; then
    EXISTING_PLIST="$(cat "${PLIST_FILE}")"
    if [[ "${EXISTING_PLIST}" == "${PLIST_CONTENT}" ]]; then
      skip "Scheduled job ${JOB_NAME} (already configured)"
      exit 0
    fi
    # Different content — unload before replacing
    launchctl bootout "gui/$(id -u)" "${PLIST_FILE}" 2>/dev/null || true
  fi

  printf '%s' "${PLIST_CONTENT}" > "${PLIST_FILE}"
  launchctl bootstrap "gui/$(id -u)" "${PLIST_FILE}"
  log "Scheduled job created: ${JOB_NAME} (every 30 min)"
  info "Manage with: launchctl list | grep ${JOB_NAME}"

else
  warn "Unsupported OS '${OS}' — skipping scheduled cass index"
fi

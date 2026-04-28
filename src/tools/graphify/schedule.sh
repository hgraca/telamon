#!/usr/bin/env bash
# Create or remove a scheduled job that updates the Graphify knowledge graph
# every 30 minutes via platform-native timers (systemd on Linux, launchd on macOS).
#
# Usage:
#   schedule.sh                    — create timer for current project
#   schedule.sh --remove <name>    — remove timer for named project
#
# Requires: PROJECT_NAME, PROJ (exported by bin/init.sh)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

# ── Parse arguments ───────────────────────────────────────────────────────────
if [[ "${1:-}" == "--remove" ]]; then
  PROJECT_NAME="${2:?Usage: schedule.sh --remove <project-name>}"
  REMOVE_MODE=true
else
  REMOVE_MODE=false
fi

OS="$(uname -s)"
JOB_NAME="graphify-update-${PROJECT_NAME}"

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
Description=Graphify incremental update for ${PROJECT_NAME}

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'cd ${PROJ} && graphify update .'"

  TIMER_CONTENT="[Unit]
Description=Graphify update timer for ${PROJECT_NAME}

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
    <string>cd '"${PROJ}"' &amp;&amp; graphify update .</string>
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
  warn "Unsupported OS '${OS}' — skipping scheduled graph updates"
fi

#!/usr/bin/env bash
# =============================================================================
# src/install/cli/install.sh
# Creates the global `telamon` CLI symlink and desktop/app menu entry.
# Idempotent: safe to re-run.
# =============================================================================

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export INSTALL_PATH

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

: "${TELAMON_ROOT:?TELAMON_ROOT is required}"

header "CLI & Desktop Entry"

# ── Symlink: ~/.local/bin/telamon ─────────────────────────────────────────────
BIN_DIR="${HOME}/.local/bin"
LINK="${BIN_DIR}/telamon"
TARGET="${TELAMON_ROOT}/bin/telamon"

mkdir -p "${BIN_DIR}"

if [[ -L "${LINK}" ]]; then
  CURRENT="$(readlink "${LINK}")"
  if [[ "${CURRENT}" == "${TARGET}" ]]; then
    skip "CLI symlink (${LINK})"
  else
    ln -sfn "${TARGET}" "${LINK}"
    log "CLI symlink updated: ${LINK} → ${TARGET}"
  fi
elif [[ -e "${LINK}" ]]; then
  warn "${LINK} exists as a regular file — not overwriting"
else
  ln -s "${TARGET}" "${LINK}"
  log "CLI symlink created: ${LINK} → ${TARGET}"
fi

# ── Desktop / App entry ───────────────────────────────────────────────────────
OS="$(os.get_os)"

ICON_SRC="${TELAMON_ROOT}/imgs/telamon-icon-128.png"

if [[ "${OS}" == "linux" ]]; then
  # ── Linux: .desktop file ──────────────────────────────────────────────────
  DESKTOP_DIR="${HOME}/.local/share/applications"
  DESKTOP_FILE="${DESKTOP_DIR}/telamon.desktop"
  ICON_DIR="${HOME}/.local/share/icons/hicolor/128x128/apps"
  ICON_DEST="${ICON_DIR}/telamon.png"

  mkdir -p "${ICON_DIR}"
  if [[ -f "${ICON_SRC}" ]]; then
    cp -f "${ICON_SRC}" "${ICON_DEST}"
  fi

  DESKTOP_CONTENT="[Desktop Entry]
Type=Application
Name=Telamon
Comment=Harness for Agentic Software Development
Exec=telamon up
Terminal=true
Icon=telamon
Categories=Development;
StartupNotify=false"

  mkdir -p "${DESKTOP_DIR}"

  if [[ -f "${DESKTOP_FILE}" ]]; then
    EXISTING="$(cat "${DESKTOP_FILE}")"
    if [[ "${EXISTING}" == "${DESKTOP_CONTENT}" ]]; then
      skip "Desktop entry (${DESKTOP_FILE})"
    else
      echo "${DESKTOP_CONTENT}" > "${DESKTOP_FILE}"
      log "Desktop entry refreshed: ${DESKTOP_FILE}"
    fi
  else
    echo "${DESKTOP_CONTENT}" > "${DESKTOP_FILE}"
    log "Desktop entry created: ${DESKTOP_FILE}"
  fi

  update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true

elif [[ "${OS}" == "macos" ]]; then
  # ── macOS: .app bundle ────────────────────────────────────────────────────
  APP_DIR="${HOME}/Applications/Telamon.app"
  MACOS_DIR="${APP_DIR}/Contents/MacOS"
  RESOURCES_DIR="${APP_DIR}/Contents/Resources"
  LAUNCHER="${MACOS_DIR}/Telamon"
  PLIST="${APP_DIR}/Contents/Info.plist"

  if [[ -d "${APP_DIR}" ]]; then
    skip "Telamon.app (${APP_DIR})"
  else
    mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

    # Copy icon for macOS app bundle
    if [[ -f "${ICON_SRC}" ]]; then
      cp -f "${ICON_SRC}" "${RESOURCES_DIR}/telamon-icon.png"
    fi

    cat > "${LAUNCHER}" <<'LAUNCHER_EOF'
#!/bin/bash
# Open Terminal and run telamon up
osascript -e 'tell application "Terminal"' \
          -e '  activate' \
          -e '  do script "telamon up"' \
          -e 'end tell'
LAUNCHER_EOF
    chmod +x "${LAUNCHER}"

    cat > "${PLIST}" <<'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Telamon</string>
  <key>CFBundleName</key>
  <string>Telamon</string>
  <key>CFBundleIdentifier</key>
  <string>com.telamon.app</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>telamon-icon.png</string>
</dict>
</plist>
PLIST_EOF

    log "Telamon.app created: ${APP_DIR}"
  fi
fi

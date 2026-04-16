#!/usr/bin/env bash
# Install Obsidian, prompt the operator to enable the Local REST API plugin
# and copy the API key, then register the MCP server in opencode.jsonc.
#
# Obsidian is a GUI app — it cannot be fully automated. After the binary is
# installed this script pauses and prints step-by-step instructions for the
# human operator. Once they press Enter it reads the API key and wires up the
# MCP block.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SECRETS_DIR="${SECRETS_DIR:-$(cd "${INSTALL_PATH}/../.." && pwd)/storage/secrets}"
export SECRETS_DIR
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Obsidian"

OS=$(os.get_os)
ARCH=$(os.get_arch)

# ── Install Obsidian binary ────────────────────────────────────────────────────
_install_obsidian_linux() {
  local tmpdir
  tmpdir="$(mktemp -d)"

  # Resolve latest release from GitHub API
  step "Resolving latest Obsidian release..."
  local api_json
  api_json="$(curl -fsSL "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest")"
  local version
  version="$(echo "${api_json}" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'].lstrip('v'))")"

  if [[ "${ARCH}" == "x86_64" ]] && command -v dpkg &>/dev/null; then
    # Prefer .deb on amd64 Debian/Ubuntu/Mint — installs to /usr/bin/obsidian
    local deb_url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/obsidian_${version}_amd64.deb"
    step "Downloading obsidian_${version}_amd64.deb..."
    curl -fsSL -o "${tmpdir}/obsidian.deb" "${deb_url}"
    step "Installing .deb package (requires sudo)..."
    sudo dpkg -i "${tmpdir}/obsidian.deb" || sudo apt-get install -f -y
  else
    # AppImage — works on any arch
    local arch_tag
    [[ "${ARCH}" == "arm64" ]] && arch_tag="-arm64" || arch_tag=""
    local appimage_url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/Obsidian-${version}${arch_tag}.AppImage"
    local dest="${HOME}/.local/bin/obsidian"
    step "Downloading Obsidian-${version}${arch_tag}.AppImage → ${dest}..."
    mkdir -p "${HOME}/.local/bin"
    curl -fsSL -o "${dest}" "${appimage_url}"
    chmod +x "${dest}"
    log "AppImage installed → ${dest}"
    info "AppImage requires FUSE. If Obsidian fails to launch, run:"
    info "  sudo apt-get install -y libfuse2   (Ubuntu/Mint/Debian)"
  fi
  rm -rf "${tmpdir}"
  log "Obsidian ${version} installed"
}

_install_obsidian_macos() {
  if command -v brew &>/dev/null; then
    step "Installing Obsidian via Homebrew Cask..."
    brew install --cask obsidian
    log "Obsidian installed via Homebrew"
  else
    # Manual DMG fallback
    local tmpdir
    tmpdir="$(mktemp -d)"

    local api_json
    api_json="$(curl -fsSL "https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest")"
    local version
    version="$(echo "${api_json}" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'].lstrip('v'))")"
    local dmg_url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/Obsidian-${version}.dmg"

    step "Downloading Obsidian-${version}.dmg..."
    curl -fsSL -o "${tmpdir}/Obsidian.dmg" "${dmg_url}"
    step "Mounting DMG and copying to /Applications..."
    hdiutil attach "${tmpdir}/Obsidian.dmg" -mountpoint "${tmpdir}/obs_mnt" -quiet
    cp -R "${tmpdir}/obs_mnt/Obsidian.app" /Applications/
    hdiutil detach "${tmpdir}/obs_mnt" -quiet
    rm -rf "${tmpdir}"
    log "Obsidian installed → /Applications/Obsidian.app"
  fi
}

if state.done "obsidian_installed"; then
  skip "Obsidian (already installed)"
else
  case "${OS}" in
    linux)  _install_obsidian_linux  ;;
    macos)  _install_obsidian_macos  ;;
    *)      warn "Unsupported OS '${OS}' — install Obsidian manually from https://obsidian.md" ;;
  esac
  state.mark "obsidian_installed"
fi

# ── Read API key ──────────────────────────────────────────────────────────────
TELAMON_ROOT="$(cd "${INSTALL_PATH}/../.." && pwd)"

# Source .env so we can check for an existing key before prompting
if [[ -f "${TELAMON_ROOT}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "${TELAMON_ROOT}/.env"; set +a
fi

_key_is_placeholder() {
  [[ -z "${OBSIDIAN_API_KEY:-}" || "${OBSIDIAN_API_KEY}" == "REPLACE_WITH_OBSIDIAN_API_KEY" ]]
}

if _key_is_placeholder; then
  # ── Human-in-the-loop: enable plugin and retrieve API key ───────────────────
  echo
  echo -e "${TEXT_BOLD}${TEXT_YELLOW}┌─────────────────────────────────────────────────────────────┐${TEXT_CLEAR}"
  echo -e "${TEXT_BOLD}${TEXT_YELLOW}│  Manual step required — Obsidian Local REST API plugin      │${TEXT_CLEAR}"
  echo -e "${TEXT_BOLD}${TEXT_YELLOW}└─────────────────────────────────────────────────────────────┘${TEXT_CLEAR}"
  echo
  echo -e "  ${TEXT_BOLD}1.${TEXT_CLEAR} Launch Obsidian and open (or create) a vault."
  echo -e "  ${TEXT_BOLD}2.${TEXT_CLEAR} Open ${TEXT_BOLD}Settings${TEXT_CLEAR} (gear icon, bottom-left)."
  echo -e "  ${TEXT_BOLD}3.${TEXT_CLEAR} Go to ${TEXT_BOLD}Community plugins${TEXT_CLEAR} → turn off Safe mode if prompted."
  echo -e "  ${TEXT_BOLD}4.${TEXT_CLEAR} Click ${TEXT_BOLD}Browse${TEXT_CLEAR} → search for ${TEXT_BOLD}Local REST API${TEXT_CLEAR} → Install → Enable."
  echo -e "  ${TEXT_BOLD}5.${TEXT_CLEAR} Still in Settings, click ${TEXT_BOLD}Local REST API${TEXT_CLEAR} (left sidebar)."
  echo -e "  ${TEXT_BOLD}6.${TEXT_CLEAR} Copy the ${TEXT_BOLD}API Key${TEXT_CLEAR} shown on that page."
  echo

  ask "Paste Obsidian API key here (or Enter to skip for now):"
  read -r -s OBSIDIAN_KEY_INPUT; echo

  if [[ -n "${OBSIDIAN_KEY_INPUT}" ]]; then
    OBSIDIAN_API_KEY="${OBSIDIAN_KEY_INPUT}"
    if [[ -f "${TELAMON_ROOT}/.env" ]] && grep -q "^OBSIDIAN_API_KEY=" "${TELAMON_ROOT}/.env"; then
      sed -i "s|^OBSIDIAN_API_KEY=.*|OBSIDIAN_API_KEY=${OBSIDIAN_API_KEY}|" "${TELAMON_ROOT}/.env"
    else
      echo "OBSIDIAN_API_KEY=${OBSIDIAN_API_KEY}" >> "${TELAMON_ROOT}/.env"
    fi
    log "OBSIDIAN_API_KEY saved to .env"
  fi

  if _key_is_placeholder; then
    warn "No Obsidian API key provided — MCP will be registered but disabled until you re-run the installer."
    OBSIDIAN_API_KEY="REPLACE_WITH_OBSIDIAN_API_KEY"
  fi
else
  skip "Obsidian API key (already set in .env)"
fi

# ── Write API key secret ───────────────────────────────────────────────────────
# Force-overwrite if we have a real key (secrets.write is idempotent / skips
# existing files, so we remove any stale placeholder first).
_secret_file="${SECRETS_DIR}/obsidian-api-key"
if [[ -f "${_secret_file}" && "${OBSIDIAN_API_KEY}" != "REPLACE_WITH_OBSIDIAN_API_KEY" ]]; then
  rm -f "${_secret_file}"
fi
secrets.write "obsidian-api-key" "${OBSIDIAN_API_KEY}"

# ── Register MCP server in opencode.jsonc ─────────────────────────────────────
# host.docker.internal resolves to the host on macOS; on Linux it is added to
# /etc/hosts by docker/install.sh pointing to the bridge gateway (172.17.0.1).
OBS_HOST="host.docker.internal"

opencode.upsert_mcp "obsidian" "$(cat <<JSON
{
  "type": "local",
  "command": [
    "docker", "run", "--rm", "-i",
    "-e", "API_KEY",
    "-e", "API_URLS",
    "oleksandrkucherenko/obsidian-mcp:latest"
  ],
  "enabled": true,
  "environment": {
    "API_KEY": "{file:.ai/telamon/secrets/obsidian-api-key}",
    "API_URLS": "[\"https://${OBS_HOST}:27124\"]"
  }
}
JSON
)"

log "Obsidian MCP registered in opencode.jsonc"

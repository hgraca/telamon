#!/usr/bin/env bash
# Install RTK (token compression proxy) via Homebrew tap and wire up OpenCode plugin.
#
# rtk init -g --opencode installs the plugin to ~/.config/opencode/plugins/rtk.ts
# (no destination override available). We copy that file into src/plugins/rtk.ts
# so it is shipped as part of the ADK and delivered to projects via the
# .opencode/plugins/adk symlink — consistent with graphify and session-capture.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "RTK (token compression)"

if ! command -v rtk &>/dev/null; then
  step "Installing RTK via Homebrew..."
  brew tap rtk-ai/tap 2>/dev/null || true
  brew install rtk-ai/tap/rtk
  log "RTK installed"
else
  skip "RTK ($(rtk --version 2>/dev/null || echo 'installed'))"
fi

# Install the OpenCode plugin to its default global location
step "Installing RTK OpenCode plugin..."
rtk init -g --opencode --auto-patch 2>/dev/null \
  && log "RTK OpenCode plugin installed" \
  || { warn "RTK init failed — run 'rtk init -g --opencode' manually after setup"; exit 0; }

# Copy from the default install location into the ADK plugin source tree
RTK_GLOBAL_PLUGIN="${HOME}/.config/opencode/plugins/rtk.ts"
RTK_ADK_PLUGIN="${ADK_ROOT}/src/plugins/rtk.ts"

if [[ -f "${RTK_GLOBAL_PLUGIN}" ]]; then
  cp "${RTK_GLOBAL_PLUGIN}" "${RTK_ADK_PLUGIN}"
  log "Copied rtk plugin → src/plugins/rtk.ts"
else
  warn "RTK global plugin not found at ${RTK_GLOBAL_PLUGIN} — skipping copy"
fi

# Register the dedupe wrapper in storage/opencode.jsonc.
# rtk.ts is kept in src/plugins/ as an import dependency of rtk-dedupe.ts
# but is NOT registered directly — only the wrapper is registered.
opencode.upsert_plugin ".opencode/plugins/adk/rtk-dedupe.ts"

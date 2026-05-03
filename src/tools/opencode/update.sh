#!/usr/bin/env bash
# Update opencode via npm.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "opencode"

if ! command -v opencode &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  opencode (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

# Determine latest upstream version
LATEST_VERSION="$(git ls-remote --tags https://github.com/anomalyco/opencode.git 'refs/tags/v[0-9]*' 2>/dev/null \
  | sed 's|.*refs/tags/v||' | sort -V -r | head -1 || echo "")"

# Check if we already have a patched build at this version
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
STATE_FILE="${TELAMON_ROOT}/storage/opencode-patch-state.json"
CONFIG_FILE="${TELAMON_ROOT}/.telamon.jsonc"
_ALREADY_PATCHED=0
_HAS_PATCHES=0

# Determine if patches are configured
if [[ -f "${CONFIG_FILE}" ]]; then
  _config_patches="$(python3 -c "
import json, re, sys
def strip(t): return re.sub(r'(?m)(?<!:)//.*\$', '', t)
with open(sys.argv[1]) as f:
    data = json.loads(strip(f.read()))
print(json.dumps(data.get('opencode_patches', [])))
" "${CONFIG_FILE}" 2>/dev/null || echo "[]")"
  _patch_count="$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "${_config_patches}")"
  [[ "${_patch_count}" -gt 0 ]] && _HAS_PATCHES=1
fi

if [[ -n "${LATEST_VERSION}" && "${_HAS_PATCHES}" -eq 1 && -f "${STATE_FILE}" ]]; then
  _state_version="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('version',''))" "${STATE_FILE}" 2>/dev/null || echo "")"
  _state_patches="$(python3 -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1])).get('patches',[])))" "${STATE_FILE}" 2>/dev/null || echo "[]")"
  _state_sha="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('binary_sha',''))" "${STATE_FILE}" 2>/dev/null || echo "")"

  # Verify: version matches, patches match, AND binary SHA still matches (not overwritten)
  if [[ "${_state_version}" == "${LATEST_VERSION}" && "${_state_patches}" == "${_config_patches}" ]]; then
    _current_sha="$(sha256sum "${HOME}/.opencode/bin/opencode" 2>/dev/null | cut -d' ' -f1 || echo "")"
    if [[ -n "${_state_sha}" && "${_current_sha}" == "${_state_sha}" ]]; then
      _ALREADY_PATCHED=1
    fi
  fi
fi

if [[ "${_ALREADY_PATCHED}" -eq 1 ]]; then
  log "opencode v${LATEST_VERSION} (patched, up to date)"
else
  if [[ "${_HAS_PATCHES}" -eq 1 ]]; then
    # Patches configured — skip npm install (we build from source, npm would
    # overwrite our binary with a stock version that may not even work)
    log "patches configured — building from source (skipping npm)"
  else
    # No patches — use npm for the stock binary
    CURRENT_VERSION="$(opencode --version 2>/dev/null || echo "0.0.0")"

    if [[ -n "${LATEST_VERSION}" && "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
      log "opencode v${CURRENT_VERSION} (already latest)"
    else
      step "Upgrading opencode via npm..."
      _npm_out="$(npm install -g opencode-ai 2>&1)" && _npm_ok=1 || _npm_ok=0

      if [[ "${_npm_ok}" -eq 1 ]]; then
        log "opencode → $(opencode --version 2>/dev/null || echo 'updated')"
      else
        warn "npm upgrade failed (non-fatal):"
        echo "${_npm_out}" | grep -i "error" | head -5 | sed 's/^/       /'
      fi
    fi
  fi

  # Apply upstream patches (if configured) — pass target version explicitly
  bash "${TOOLS_PATH}/opencode/apply-patches.sh" "${LATEST_VERSION}" || true
fi

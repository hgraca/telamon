#!/usr/bin/env bash
# Update opencode via npm.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)
#
# NOTE: Upstream PR patches are NOT applied here. Run `/patch-opencode` from
# inside an opencode session to rebuild a patched binary on demand.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "opencode"

if ! command -v opencode &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  opencode (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

CURRENT_VERSION="$(opencode --version 2>/dev/null || echo "0.0.0")"

# If the running binary was patched (`/patch-opencode` stamps version 666.0.0),
# leave it alone — npm would clobber the patched build.
if [[ "${CURRENT_VERSION}" == "666.0.0" ]]; then
  log "opencode v${CURRENT_VERSION} (patched build — skipping npm update; run /patch-opencode to refresh)"
  exit 0
fi

LATEST_VERSION="$(git ls-remote --tags https://github.com/anomalyco/opencode.git 'refs/tags/v[0-9]*' 2>/dev/null \
  | sed 's|.*refs/tags/v||' | sort -V -r | head -1 || echo "")"

if [[ -n "${LATEST_VERSION}" && "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
  log "opencode v${CURRENT_VERSION} (already latest)"
  exit 0
fi

step "Upgrading opencode via npm..."
_npm_out="$(npm install -g opencode-ai 2>&1)" && _npm_ok=1 || _npm_ok=0

if [[ "${_npm_ok}" -eq 1 ]]; then
  log "opencode → $(opencode --version 2>/dev/null || echo 'updated')"
else
  warn "npm upgrade failed (non-fatal):"
  echo "${_npm_out}" | grep -i "error" | head -5 | sed 's/^/       /'
  exit 1
fi

# ── Refresh @opencode-ai/plugin for custom tools ──────────────────────────────
# Re-run bun install so that any version bump in src/instructions/tools/package.json
# (delivered by a telamon update) gets picked up. Idempotent and fast when nothing
# has changed. See brain/gotchas.md "Opencode custom tools require flat layout AND
# co-located node_modules" (2026-05-10).
TELAMON_ROOT="$(cd "${TOOLS_PATH}/../.." && pwd)"
TOOLS_SRC="${TELAMON_ROOT}/src/instructions/tools"
if [[ -f "${TOOLS_SRC}/package.json" ]]; then
  if command -v bun &>/dev/null; then
    step "Refreshing custom-tool dependencies (@opencode-ai/plugin)..."
    if (cd "${TOOLS_SRC}" && bun install) >/dev/null 2>&1; then
      log "Custom-tool deps refreshed → ${TOOLS_SRC}/node_modules/"
    else
      warn "bun install failed in ${TOOLS_SRC} — custom tools may not load"
    fi
  else
    warn "bun not found — cannot refresh @opencode-ai/plugin; custom tools may run with stale version"
  fi
fi

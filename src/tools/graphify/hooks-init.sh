#!/usr/bin/env bash
# Install graphify git hooks into a project.
# Hooks trigger background graphify updates on branch switch and commit.
#
# Requires: PROJ (absolute or relative path to the target project)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

PROJ="${PROJ:?PROJ env var is required}"
PROJ="$(cd "${PROJ}" && pwd)"

HOOKS_DIR="${PROJ}/.git/hooks"
RUNNER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/graphify-hook-runner.sh"

MARKER_START="# ── TELAMON GRAPHIFY START ──"
MARKER_END="# ── TELAMON GRAPHIFY END ──"

if [[ ! -d "${HOOKS_DIR}" ]]; then
  warn "No .git/hooks directory found in ${PROJ} — skipping git hook installation"
  exit 0
fi

# ── Install a single hook ─────────────────────────────────────────────────────
install_hook() {
  local hook_file="${HOOKS_DIR}/$1"
  local hook_body="$2"
  local section
  section="$(printf '%s\n%s\n%s\n' "${MARKER_START}" "${hook_body}" "${MARKER_END}")"

  if [[ -f "${hook_file}" ]]; then
    # Remove existing telamon section (idempotent)
    local tmp
    tmp="$(mktemp)"
    awk "
      /^${MARKER_START//\//\\/}$/ { skip=1; next }
      /^${MARKER_END//\//\\/}$/   { skip=0; next }
      !skip { print }
    " "${hook_file}" > "${tmp}"
    # Strip leading and trailing blank lines from existing content, then append
    # section. Without trimming, an empty hook file (after removing the telamon
    # section) would produce leading blank lines in the output.
    local existing
    existing="$(sed -e '/./,$!d' -e 's/[[:space:]]*$//' "${tmp}" | sed -e :a -e '/^\n*$/{$d;N;ba}')"
    if [[ -n "${existing}" ]]; then
      printf '%s\n\n%s\n' "${existing}" "${section}" > "${hook_file}"
    else
      printf '%s\n' "${section}" > "${hook_file}"
    fi
    rm -f "${tmp}"
  else
    printf '#!/usr/bin/env bash\n\n%s\n' "${section}" > "${hook_file}"
  fi

  chmod +x "${hook_file}"
}

# ── post-checkout: only trigger on branch switch (3rd arg == 1) ───────────────
POST_CHECKOUT_BODY="# Args: prev-ref new-ref branch-flag
if [[ \"\${3:-0}\" == \"1\" ]]; then
  bash \"${RUNNER}\" \"${PROJ}\" &
fi"

# ── post-commit: always trigger ───────────────────────────────────────────────
POST_COMMIT_BODY="bash \"${RUNNER}\" \"${PROJ}\" &"

install_hook "post-checkout" "${POST_CHECKOUT_BODY}"
install_hook "post-commit"   "${POST_COMMIT_BODY}"

log "Graphify git hooks installed in ${PROJ}"

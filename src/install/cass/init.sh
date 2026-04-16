#!/usr/bin/env bash
# Install a post-commit git hook in the current project that runs
# `cass index` (incremental) after each commit, keeping the session
# search index current automatically — the same strategy as graphify.
#
# The hook block is wrapped in # cass-hook-start / # cass-hook-end markers
# so it can be appended safely to an existing post-commit hook and
# detected on re-runs (idempotent).

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "cass git hook"

if ! command -v cass &>/dev/null; then
  warn "cass not found — skipping git hook installation"
  return 0 2>/dev/null || exit 0
fi

if [[ ! -d ".git" ]]; then
  warn "Not a git repository — skipping cass hook installation"
  return 0 2>/dev/null || exit 0
fi

HOOK_FILE=".git/hooks/post-commit"
HOOK_BLOCK='# cass-hook-start
# Incrementally updates the cass session search index after each commit.
# Installed by: ADK cass/init.sh
if command -v cass >/dev/null 2>&1; then
    cass index >/dev/null 2>&1 &
fi
# cass-hook-end'

# Check if hook block already installed
if [[ -f "${HOOK_FILE}" ]] && grep -q "cass-hook-start" "${HOOK_FILE}"; then
  skip "cass post-commit hook (already installed)"
  return 0 2>/dev/null || exit 0
fi

step "Installing cass post-commit hook..."

if [[ ! -f "${HOOK_FILE}" ]]; then
  # Create new hook file
  printf '#!/bin/sh\n%s\n' "${HOOK_BLOCK}" > "${HOOK_FILE}"
else
  # Append to existing hook
  printf '\n%s\n' "${HOOK_BLOCK}" >> "${HOOK_FILE}"
fi

chmod +x "${HOOK_FILE}"
log "cass post-commit hook installed → .git/hooks/post-commit"
info "cass index will run incrementally in the background after each commit."

#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/qmd-refresh/qmd-refresh.sh
# CLI wrapper for the qmd-refresh tool — runs `qmd update && qmd embed`
# in the background (fire-and-forget).
#
# Usage:
#   telamon tool qmd-refresh          # launch in background, return immediately
#   qmd-refresh.sh                    # same, direct invocation
#
# The command is launched detached so it never blocks the caller.
# All output from qmd is discarded (>/dev/null 2>&1).
# =============================================================================

set -euo pipefail

if ! command -v qmd &>/dev/null; then
  echo "Error: qmd binary not found in PATH" >&2
  exit 1
fi

# Fire-and-forget: launch detached, discard output, return immediately.
# Equivalent to: qmd update && qmd embed >/dev/null 2>&1 & disown
bash -c 'qmd update && qmd embed >/dev/null 2>&1 &' &
disown 2>/dev/null || true

echo '{"status":"ok","message":"qmd update && qmd embed launched in background"}'

#!/usr/bin/env bash
# =============================================================================
# src/functions/symlink.sh
# Symlink-management helpers shared across init/update scripts.
#
# Functions:
#   ensure_symlink <link_path> <expected_target> [label]
#       Idempotently ensure <link_path> is a symlink pointing at
#       <expected_target>. Creates if missing, repairs if pointing elsewhere,
#       skips if already correct, warns if a non-symlink occupies the path.
#       <label> is the human-readable label for log messages
#       (defaults to <link_path>).
# =============================================================================

# ensure_symlink <link_path> <expected_target> [label]
ensure_symlink() {
  local _link="$1" _target="$2" _label="${3:-$1}"
  if [[ -L "${_link}" ]]; then
    local _current
    _current="$(readlink "${_link}")"
    if [[ "${_current}" == "${_target}" ]]; then
      skip "${_label} (already correct)"
    else
      rm "${_link}"
      ln -s "${_target}" "${_link}"
      log "Repaired ${_label} → ${_target} (was: ${_current})"
    fi
  elif [[ -e "${_link}" ]]; then
    warn "${_label} exists but is not a symlink — skipping"
  else
    ln -s "${_target}" "${_link}"
    log "Symlinked ${_label} → ${_target}"
  fi
}

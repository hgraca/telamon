#!/usr/bin/env bash

# secrets.write — idempotent secret file writer.
#
# Usage:
#   secrets.write [--force] <name> <value>
#
# Writes <value> to "${SECRETS_DIR}/<name>" with mode 600.
# If the file already exists, it is left unchanged (idempotent) unless
# --force is passed, in which case the file is always overwritten.
# SECRETS_DIR must be exported by the caller (set by run.sh).

secrets.write() {
  local force=0
  if [[ "${1:-}" == "--force" ]]; then
    force=1
    shift
  fi

  local name="${1:?secrets.write: name is required}"
  local value="${2:?secrets.write: value is required}"
  local secrets_dir="${SECRETS_DIR:?SECRETS_DIR is not set — make sure run.sh exported it}"
  local dest="${secrets_dir}/${name}"

  mkdir -p "${secrets_dir}"

  if [[ -f "${dest}" && "${force}" -eq 0 ]]; then
    skip "Secret '${name}' (already exists — skipping)"
    return 0
  fi

  printf '%s' "${value}" > "${dest}"
  chmod 600 "${dest}"
  log "Secret written → ${dest}"
}

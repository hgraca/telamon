#!/usr/bin/env bash
# Resolve an app name to its absolute install dir.
#
# Checks ${PREREQUISITES_PATH}/<name> first, then ${MODULES_PATH}/<name>.
# Echoes the absolute path on success, returns 1 if not found.
#
# Both PREREQUISITES_PATH and MODULES_PATH must be set in the calling
# environment (typically by bin/install.sh, bin/init.sh, bin/update.sh,
# bin/doctor.sh).
_resolve_app_path() {
  local _name="$1"
  if [[ -d "${PREREQUISITES_PATH}/${_name}" ]]; then
    printf '%s\n' "${PREREQUISITES_PATH}/${_name}"
    return 0
  fi
  if [[ -d "${MODULES_PATH}/${_name}" ]]; then
    printf '%s\n' "${MODULES_PATH}/${_name}"
    return 0
  fi
  return 1
}

#!/usr/bin/env bash

# env.is_enabled — check whether an optional service flag is set to true.
#
# Usage:
#   env.is_enabled <VAR_NAME>
#
# Returns 0 (true) if the named variable is "true" (case-insensitive).
# Returns 1 (false) otherwise.
#
# Resolution order:
#   1. Already-exported environment variable (${!VAR_NAME}).
#   2. Falls back to reading the value from ${TELAMON_ROOT}/.env.
#      TELAMON_ROOT must be set; fails loudly if not.

env.is_enabled() {
  local var_name="${1:?env.is_enabled: variable name is required}"
  local value="${!var_name:-}"

  if [[ -z "${value}" ]]; then
    local env_file="${TELAMON_ROOT:?TELAMON_ROOT must be set}/.env"
    if [[ -f "${env_file}" ]]; then
      value="$(grep -E "^[[:space:]]*${var_name}[[:space:]]*=" "${env_file}" | head -1 | cut -d= -f2- | tr -d "\"' ")"
    fi
  fi

  [[ "${value}" =~ ^[Tt][Rr][Uu][Ee]$ ]]
}

# env.is_disabled — check whether an optional service flag is explicitly set to false.
#
# Usage:
#   env.is_disabled <VAR_NAME>
#
# Returns 0 (true) if the named variable is "false" (case-insensitive).
# Returns 1 (false) otherwise (including when the value is empty/unset).
#
# Resolution order: same as env.is_enabled.

env.is_disabled() {
  local var_name="${1:?env.is_disabled: variable name is required}"
  local value="${!var_name:-}"

  if [[ -z "${value}" ]]; then
    local env_file="${TELAMON_ROOT:?TELAMON_ROOT must be set}/.env"
    if [[ -f "${env_file}" ]]; then
      value="$(grep -E "^[[:space:]]*${var_name}[[:space:]]*=" "${env_file}" | head -1 | cut -d= -f2- | tr -d "\"' ")"
    fi
  fi

  [[ "${value}" =~ ^[Ff][Aa][Ll][Ss][Ee]$ ]]
}

# env.read — read the raw value of a variable from the environment or .env file.
#
# Usage:
#   env.read <VAR_NAME>
#
# Prints the value (may be empty). Returns 0 always.

env.read() {
  local var_name="${1:?env.read: variable name is required}"
  local value="${!var_name:-}"

  if [[ -z "${value}" ]]; then
    local env_file="${TELAMON_ROOT:?TELAMON_ROOT must be set}/.env"
    if [[ -f "${env_file}" ]]; then
      value="$(grep -E "^[[:space:]]*${var_name}[[:space:]]*=" "${env_file}" | head -1 | cut -d= -f2- | tr -d "\"' ")"
    fi
  fi

  printf '%s' "${value}"
}

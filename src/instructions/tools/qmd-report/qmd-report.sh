#!/usr/bin/env bash
# =============================================================================
# src/instructions/tools/qmd-report/qmd-report.sh
# CLI wrapper for the qmd-report tool — searches the project memory vault via
# QMD and returns full file contents as Markdown.
#
# Usage:
#   telamon tool qmd-report billing                    # positional → --query
#   telamon tool qmd-report "planning workflow"         # multi-word query
#   telamon tool qmd-report billing --collection core   # explicit collection
#   telamon tool qmd-report --query billing             # explicit flag
#
# Positional args are converted to --query flags. Explicit --flags pass through
# with their values.
#
# Defaults (from .ai/telamon/telamon.jsonc):
#   --collection: project_name
#   --format:     markdown
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELAMON_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"

TOOL_SCRIPT="${TELAMON_ROOT}/src/instructions/tools/qmd-report/qmd-report.py"

if [[ ! -f "${TOOL_SCRIPT}" ]]; then
  echo "Error: qmd-report.py not found at ${TOOL_SCRIPT}" >&2
  exit 1
fi

# Resolve defaults from project config
PROJECT_NAME="telamon"
TELAMON_CONFIG="${TELAMON_ROOT}/.ai/telamon/telamon.jsonc"
if [[ -f "${TELAMON_CONFIG}" ]]; then
  CONFIG_PROJECT="$(python3 -c "import json; print(json.load(open('${TELAMON_CONFIG}')).get('project_name',''))" 2>/dev/null || true)"
  if [[ -n "${CONFIG_PROJECT}" ]]; then
    PROJECT_NAME="${CONFIG_PROJECT}"
  fi
fi

# Parse args: positional → --query, explicit --flags pass through with values
# Inject defaults for --collection and --format if not explicitly provided
HAS_COLLECTION=false
HAS_FORMAT=false
ARGS=()
NEXT_IS_VALUE=false
NEXT_IS_FLAG=""
for arg in "$@"; do
  if $NEXT_IS_VALUE; then
    ARGS+=("${arg}")
    if [[ "${NEXT_IS_FLAG}" == "--collection" ]]; then HAS_COLLECTION=true; fi
    if [[ "${NEXT_IS_FLAG}" == "--format" ]]; then HAS_FORMAT=true; fi
    NEXT_IS_VALUE=false
    NEXT_IS_FLAG=""
  elif [[ "${arg}" == --* ]]; then
    ARGS+=("${arg}")
    NEXT_IS_VALUE=true
    NEXT_IS_FLAG="${arg}"
  else
    ARGS+=("--query" "${arg}")
  fi
done

# Inject defaults for missing flags
if ! $HAS_COLLECTION; then
  ARGS+=("--collection" "${PROJECT_NAME}")
fi
if ! $HAS_FORMAT; then
  ARGS+=("--format" "markdown")
fi

# Set QMD environment: redirect cache to Telamon storage, enable GPU
export XDG_CACHE_HOME="${TELAMON_ROOT}/storage"
export QMD_LLAMA_GPU=true

exec python3 "${TOOL_SCRIPT}" "${ARGS[@]}"
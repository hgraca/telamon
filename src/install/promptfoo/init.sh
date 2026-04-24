#!/usr/bin/env bash
# Scaffold tests/agents/ directory in the current project.
# Copies promptfooconfig.yaml and package.json templates.
# Idempotent: skipped if config already exists.
# Does NOT run npm install — manual post-init step.
#
# Only runs when WITH_TESTS=true (set by bin/init.sh --with-tests).

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "promptfoo Eval Config"

if [[ "${WITH_TESTS:-false}" != "true" ]]; then
  skip "promptfoo config (--with-tests not set)"; exit 0
fi

EVAL_DIR="$(pwd)/tests/agents"

if [[ -f "${EVAL_DIR}/promptfooconfig.yaml" ]]; then
  skip "promptfoo config (already exists)"; exit 0
fi

mkdir -p "${EVAL_DIR}/evals" "${EVAL_DIR}/fixtures"
cp "${SCRIPT_DIR}/promptfooconfig.yaml" "${EVAL_DIR}/promptfooconfig.yaml"
cp "${SCRIPT_DIR}/package.json" "${EVAL_DIR}/package.json"
log "Eval config written → tests/agents/promptfooconfig.yaml"
log "Run 'cd tests/agents && npm install' before first eval"

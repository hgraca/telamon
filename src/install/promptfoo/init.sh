#!/usr/bin/env bash
# Scaffold test/eval/ directory in the current project.
# Copies promptfooconfig.yaml and package.json templates.
# Idempotent: skipped if config already exists.
# Does NOT run npm install — manual post-init step.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "promptfoo Eval Config"

EVAL_DIR="$(pwd)/test/eval"

if [[ -f "${EVAL_DIR}/promptfooconfig.yaml" ]]; then
  skip "promptfoo config (already exists)"; exit 0
fi

mkdir -p "${EVAL_DIR}/evals" "${EVAL_DIR}/fixtures"
cp "${SCRIPT_DIR}/promptfooconfig.yaml" "${EVAL_DIR}/promptfooconfig.yaml"
cp "${SCRIPT_DIR}/package.json" "${EVAL_DIR}/package.json"
log "Eval config written → test/eval/promptfooconfig.yaml"
log "Run 'cd test/eval && npm install' before first eval"

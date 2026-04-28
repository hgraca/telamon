#!/usr/bin/env bash
set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Diff Context"

opencode.upsert_plugin ".opencode/plugins/telamon/diff-context.js"

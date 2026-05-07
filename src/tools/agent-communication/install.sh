#!/usr/bin/env bash
set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Status Marker Enforcer"

opencode.upsert_plugin ".opencode/plugins/telamon/agent-communication.js"

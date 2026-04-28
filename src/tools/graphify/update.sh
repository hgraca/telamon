#!/usr/bin/env bash
# Update graphify via uv.
# Exit codes: 0=success  1=failed  2=not-installed (skipped)

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Graphify"

if ! command -v graphify &>/dev/null; then
  echo -e "  ${TEXT_DIM}–  graphify (not installed — skipping)${TEXT_CLEAR}"
  exit 2
fi

step "Upgrading graphify via uv..."
uv tool upgrade graphifyy 2>/dev/null \
  && log "graphify → $(graphify --version 2>/dev/null || echo 'updated')" \
  || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  graphify upgrade failed — try: uv tool upgrade graphifyy"; exit 1; }

# Restore --with dependencies stripped by uv tool upgrade
step "Restoring MCP dependency..."
uv tool install graphifyy --with mcp --force 2>/dev/null || true

# ── Rebuild missing graphs for initialized projects ──────────────────────────
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
for storage_dir in "${TELAMON_ROOT}/storage/graphify"/*/; do
  [[ -d "${storage_dir}" ]] || continue
  [[ -f "${storage_dir}graph.json" ]] && continue
  [[ -f "${storage_dir}.project-path" ]] || continue
  proj="$(cat "${storage_dir}.project-path")"
  [[ -d "${proj}" ]] || { warn "Project directory not found: ${proj} — skipping graph build"; continue; }
  PROJ_NAME=$(basename "${proj}")
  DATE_STR=$(date '+%-d %b %Y, %H:%M')
  info "${DATE_STR} — Building missing graph for ${PROJ_NAME}..."
  TMPOUT=$(mktemp)
  START_SECS=${SECONDS}
  (cd "${proj}" && graphify update . 2>&1) | tee "${TMPOUT}" && GRAPH_EXIT=0 || GRAPH_EXIT=$?
  ELAPSED=$(( SECONDS - START_SECS ))

  if [[ ${GRAPH_EXIT} -ne 0 ]]; then
    warn "graphify build failed for ${PROJ_NAME} — continuing"
  else
    NODES=$(grep -oP '\d+(?= nodes)'       "${TMPOUT}" | tail -1 || echo "?")
    EDGES=$(grep -oP '\d+(?= edges)'       "${TMPOUT}" | tail -1 || echo "?")
    COMMUNITIES=$(grep -oP '\d+(?= communities)' "${TMPOUT}" | tail -1 || echo "?")
    DURATION=$(_fmt_duration ${ELAPSED})

    echo -e ""
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}┌─ Knowledge Graph Summary (${PROJ_NAME}) ────────────────┐${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_GREEN}✔${TEXT_CLEAR}  Nodes            : ${TEXT_BOLD}${NODES}${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_GREEN}✔${TEXT_CLEAR}  Edges            : ${TEXT_BOLD}${EDGES}${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_GREEN}✔${TEXT_CLEAR}  Communities      : ${TEXT_BOLD}${COMMUNITIES}${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}⏱${TEXT_CLEAR}  Duration         : ${DURATION}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}└───────────────────────────────────────────────────────┘${TEXT_CLEAR}"
  fi
  rm -f "${TMPOUT}"
done

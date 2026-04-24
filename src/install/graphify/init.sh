#!/usr/bin/env bash
# Set up Graphify in the current project: redirect graphify-out to
# per-project storage, symlink MCP wrapper, and build initial graph.
#
# graphify always writes to ./graphify-out relative to CWD. We redirect it
# to <telamon-root>/storage/graphify via a symlink so all output is centralised
# and never scattered across the project tree.
#
# The plugin entry (".opencode/plugins/telamon/graphify.js") is already present in
# storage/opencode.jsonc (added by graphify/install.sh during `make up`).
# Projects receive the plugin JS via the .opencode/plugins/telamon symlink created
# by `make init` — no copying is needed.
# For projects with their own opencode config it flows in via merge-config.py
# in bin/init.sh.
#
# The graphify skill is shipped as a static file in src/skills/memory/_tools/graphify/SKILL.md
# and is made available to projects via the .opencode/skills/telamon symlink created
# by `make init`. No download or copying is needed.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "Graphify"

if ! command -v graphify &>/dev/null; then
  warn "graphify not found — skipping project setup"
  return 0 2>/dev/null || exit 0
fi

# ── Redirect graphify-out → <telamon-root>/storage/graphify/<project-name> ───────
# graphify hardcodes ./graphify-out as its output directory. A symlink at the
# project root redirects all output to Telamon's central storage location.
GRAPHIFY_STORAGE="${TELAMON_ROOT}/storage/graphify/${PROJECT_NAME}"

if [[ -f "${TELAMON_ROOT}/storage/graphify/graph.json" ]]; then
  warn "Detected old flat graphify layout at storage/graphify/graph.json. Delete it and re-run init."
fi

mkdir -p "${GRAPHIFY_STORAGE}"
echo -n "$(pwd)" > "${GRAPHIFY_STORAGE}/.project-path"

if [[ -L "graphify-out" ]]; then
  skip "graphify-out symlink (already exists)"
elif [[ -d "graphify-out" ]]; then
  warn "graphify-out is a real directory — moving contents to storage/graphify and replacing with symlink"
  cp -r graphify-out/. "${GRAPHIFY_STORAGE}/"
  rm -rf graphify-out
  ln -s "${GRAPHIFY_STORAGE}" graphify-out
  log "graphify-out → ${GRAPHIFY_STORAGE}"
else
  ln -s "${GRAPHIFY_STORAGE}" graphify-out
  log "Symlinked graphify-out → ${GRAPHIFY_STORAGE}"
fi

# ── Symlink MCP wrapper ──────────────────────────────────────────────────────
if [[ -d ".opencode" ]]; then
  ln -sf "${TELAMON_ROOT}/src/install/graphify/serve-wrapper.sh" .opencode/graphify-serve.sh
  log "Symlinked .opencode/graphify-serve.sh"
else
  warn ".opencode/ directory not found — skipping MCP wrapper symlink"
fi

# ── Build initial knowledge graph ────────────────────────────────────────────
if [[ -f "graphify-out/graph.json" ]]; then
  skip "Graph already built"
else
  DATE_STR=$(date '+%-d %b %Y, %H:%M')
  info "${DATE_STR} — Building initial knowledge graph..."
  TMPOUT=$(mktemp)
  START_SECS=${SECONDS}
  graphify update . 2>&1 | tee "${TMPOUT}" && GRAPH_EXIT=0 || GRAPH_EXIT=$?
  ELAPSED=$(( SECONDS - START_SECS ))

  if [[ ${GRAPH_EXIT} -ne 0 ]]; then
    warn "graphify build failed — continuing without graph"
  else
    NODES=$(grep -oP '\d+(?= nodes)'       "${TMPOUT}" | tail -1 || echo "?")
    EDGES=$(grep -oP '\d+(?= edges)'       "${TMPOUT}" | tail -1 || echo "?")
    COMMUNITIES=$(grep -oP '\d+(?= communities)' "${TMPOUT}" | tail -1 || echo "?")
    DURATION=$(_fmt_duration ${ELAPSED})

    echo -e ""
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}┌─ Knowledge Graph Summary ─────────────────────────────┐${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_GREEN}✔${TEXT_CLEAR}  Nodes            : ${TEXT_BOLD}${NODES}${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_GREEN}✔${TEXT_CLEAR}  Edges            : ${TEXT_BOLD}${EDGES}${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_GREEN}✔${TEXT_CLEAR}  Communities      : ${TEXT_BOLD}${COMMUNITIES}${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}⏱${TEXT_CLEAR}  Duration         : ${DURATION}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}Available tools:${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}  query_graph · get_node · get_neighbors${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}  get_community · god_nodes · shortest_path${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}└───────────────────────────────────────────────────────┘${TEXT_CLEAR}"
  fi
  rm -f "${TMPOUT}"
fi

# ── Schedule periodic graph updates ──────────────────────────────────────────
step "Scheduling 30-min graph update..."
bash "${INSTALL_PATH}/graphify/schedule.sh" || warn "Failed to create scheduled job — graph updates will need manual runs"

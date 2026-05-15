#!/usr/bin/env bash
# Set up Graphify in the current project: redirect graphify-out to
# per-project storage, symlink MCP wrapper, and build initial graph.
#
# graphify always writes to ./graphify-out relative to CWD. We redirect it
# to <telamon-root>/storage/graphify via a symlink so all output is centralised
# and never scattered across the project tree.
#
# The graphify context injection plugin was retired — context priming is now
# handled by a single context priming tool at session start.
#
# The graphify skill is shipped as a static file in src/instructions/skills/memory/_tools/graphify/SKILL.md
# and is made available to projects via the .opencode/skills/telamon symlink created
# by `make init`. No download or copying is needed.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

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

if [[ -d "graphify-out" && ! -L "graphify-out" ]]; then
  warn "graphify-out is a real directory — moving contents to storage/graphify and replacing with symlink"
  cp -r graphify-out/. "${GRAPHIFY_STORAGE}/"
  rm -rf graphify-out
fi
ensure_symlink "graphify-out" "${GRAPHIFY_STORAGE}" "graphify-out"

# ── Symlink MCP wrapper ──────────────────────────────────────────────────────
if [[ -d ".opencode" ]]; then
  ln -sf "${TELAMON_ROOT}/src/modules/graphify/serve-wrapper.sh" .opencode/graphify-serve.sh
  log "Symlinked .opencode/graphify-serve.sh"
else
  warn ".opencode/ directory not found — skipping MCP wrapper symlink"
fi

# ── Build initial knowledge graph ────────────────────────────────────────────
if [[ -f "graphify-out/graph.json" ]]; then
  skip "Graph already built"
else
  # Sync .gitignore → .graphifyignore before building
  if [[ -f ".gitignore" ]]; then
    _MARKER="# ── AUTO-GENERATED FROM .gitignore ──"
    _content="$(printf '%s\n# Do not edit this section manually — it is regenerated on each commit.\n# Add custom patterns below the END marker.\n\n' "${_MARKER}")"
    _content+="$(cat .gitignore)"
    _content+="$(printf '\n\n# ── END AUTO-GENERATED ──\n')"
    printf '%s' "${_content}" > .graphifyignore
    log "Created .graphifyignore from .gitignore"
  fi

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
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}  graphify query · graphify path · graphify explain${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}│${TEXT_CLEAR}  ${TEXT_DIM}  graphify-report (custom tool)${TEXT_CLEAR}"
    echo -e "  ${TEXT_BOLD}${TEXT_BLUE}└───────────────────────────────────────────────────────┘${TEXT_CLEAR}"
  fi
  rm -f "${TMPOUT}"
fi

# ── Install graphify git hooks ────────────────────────────────────────────────
step "Installing graphify git hooks..."

GRAPHIFY_RUNNER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/graphify-hook-runner.sh"

# Background + disown — prevents MCP git server from waiting on child processes
# (Python subprocess waits until inherited FDs close).
PROJ_ABS="$(cd "${PROJ}" && pwd)"

# post-checkout: fire only on actual branch switch (3rd arg from git == 1).
POST_CHECKOUT_BODY="# Args: prev-ref new-ref branch-flag
if [[ \"\${3:-0}\" == \"1\" ]]; then
  bash \"${GRAPHIFY_RUNNER}\" \"${PROJ_ABS}\" >/dev/null 2>&1 & disown
fi"

# post-commit: rebuild graph in the background.
POST_COMMIT_BODY="bash \"${GRAPHIFY_RUNNER}\" \"${PROJ_ABS}\" >/dev/null 2>&1 & disown"

PROJ="${PROJ_ABS}" install_telamon_hook "post-checkout" "${POST_CHECKOUT_BODY}" "GRAPHIFY" \
  || warn "Failed to install graphify post-checkout hook"
PROJ="${PROJ_ABS}" install_telamon_hook "post-commit"   "${POST_COMMIT_BODY}" "GRAPHIFY" \
  || warn "Failed to install graphify post-commit hook"

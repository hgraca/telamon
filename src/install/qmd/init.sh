#!/usr/bin/env bash
# Register QMD collections for the current project's Obsidian vault and run
# the initial embedding pass.
#
# The vault lives at <adk-root>/storage/obsidian/<project-name>/ and is
# symlinked into the project at <project>/.ai/adk/memory/.
# The bootstrap/ subfolder is intentionally excluded from QMD — it is loaded
# via AGENTS.md and does not benefit from semantic search.
#
# One collection is registered per vault section so the agent can query a
# specific area without noise from unrelated content:
#
#   <project>-brain      brain/        — memories, decisions, patterns, gotchas
#   <project>-work       work/         — active tasks, archive, incidents
#   <project>-reference  reference/    — architecture maps, flow docs
#   <project>-thinking   thinking/     — scratchpad drafts
#
# Collections are registered in the ADK-managed index at
# <adk-root>/storage/qmd/index.sqlite (XDG_CACHE_HOME override).
# Re-running this script is safe (collection add is idempotent).
#
# The initial `qmd embed` can take a few minutes the first time because QMD
# downloads its local GGUF models (~2 GB) on first use.

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

header "QMD vault collections"

# ── Redirect QMD cache to ADK storage ─────────────────────────────────────────
# All qmd commands in this script run with XDG_CACHE_HOME set so the index and
# model cache live at storage/qmd/ instead of the system-wide ~/.cache/qmd/.
export XDG_CACHE_HOME="${ADK_ROOT}/storage"
mkdir -p "${ADK_ROOT}/storage/qmd"

# ── Guard: qmd must be installed ──────────────────────────────────────────────
if ! command -v qmd &>/dev/null; then
  warn "qmd not found — skipping vault collection setup"
  warn "Install with: npm install -g @tobilu/qmd"
  return 0 2>/dev/null || exit 0
fi

# ── Resolve project name from adk.ini or directory basename ──────────────────
# When called from bin/init.sh we are cd'd into the project root, which has
# .ai/adk/adk.ini written in step 3.  Fall back to the directory basename.
ADK_INI="${PWD}/.ai/adk/adk.ini"
if [[ -f "${ADK_INI}" ]]; then
  PROJECT_NAME="$(grep -E '^project_name\s*=' "${ADK_INI}" | head -1 | sed 's/.*=\s*//' | tr -d '[:space:]')"
else
  PROJECT_NAME="$(basename "${PWD}")"
fi

if [[ -z "${PROJECT_NAME}" ]]; then
  warn "Could not determine project name — skipping QMD collection setup"
  return 0 2>/dev/null || exit 0
fi

VAULT="${ADK_ROOT}/storage/obsidian/${PROJECT_NAME}"

if [[ ! -d "${VAULT}" ]]; then
  warn "Vault not found at ${VAULT} — run 'make init PROJ=<path>' first"
  return 0 2>/dev/null || exit 0
fi

# ── Register collections ───────────────────────────────────────────────────────
# `qmd collection add` is idempotent: re-running updates the path if it changed
# but does not duplicate entries.

declare -A COLLECTIONS=(
  ["brain"]="memories, key decisions, patterns, and recurring gotchas for ${PROJECT_NAME}"
  ["work"]="active tasks, archived work, and incidents for ${PROJECT_NAME}"
  ["reference"]="architecture maps, flow docs, and reference material for ${PROJECT_NAME}"
  ["thinking"]="scratchpad drafts and exploratory notes for ${PROJECT_NAME}"
)

for section in brain work reference thinking; do
  dir="${VAULT}/${section}"
  name="${PROJECT_NAME}-${section}"
  description="${COLLECTIONS[$section]}"

  if [[ ! -d "${dir}" ]]; then
    info "Skipping ${name} (${dir} does not exist yet)"
    continue
  fi

  step "Registering QMD collection: ${name} ..."
  qmd collection add "${dir}" --name "${name}" --mask "**/*.md" 2>/dev/null \
    && log "Collection registered: ${name}" \
    || warn "qmd collection add failed for ${name} — retry: qmd collection add ${dir} --name ${name} --mask '**/*.md'"

  step "Adding QMD context for ${name} ..."
  qmd context add "qmd://${name}" "${description}" 2>/dev/null || true
done

# ── Initial index + embed ─────────────────────────────────────────────────────
# `qmd update` scans collections for new/changed files and enqueues them.
# `qmd embed` runs the embedding model on the enqueued files.
# Both are fast on subsequent runs (incremental) but the first run downloads
# the GGUF models if not already cached.

step "Building initial QMD index (this may take a few minutes on first run) ..."
info "QMD will download ~2 GB of local GGUF models on first run if not cached."

if qmd update 2>/dev/null && qmd embed 2>/dev/null; then
  log "QMD index built for ${PROJECT_NAME}"
else
  warn "QMD indexing did not complete cleanly — run manually: qmd update && qmd embed"
  warn "This is normal if the models are still downloading."
fi

info "Vault collections registered for '${PROJECT_NAME}'."
info "Query: qmd query '<question>' -n 10"
info "Search: qmd search '<keywords>'"

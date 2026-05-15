#!/usr/bin/env bash
# Register a single QMD collection for the current project's latent/ folder and
# run the initial embedding pass.
#
# Only latent/ is indexed — it contains the structured, per-item knowledge files
# (memories, ADRs, PDRs, gotchas, patterns) that benefit from semantic search.
# Work archives, thinking/, reference/, and bootstrap/ are excluded.
#
# The vault lives at <telamon-root>/storage/memory/projects/<project-name>/ and
# is symlinked into the project at <project>/.ai/telamon/memory/. The collection
# is registered using the symlink path so it works uniformly across both
# memory-owner modes (telamon and project).
#
# A SINGLE collection is registered per project, named after the project:
#
#   <project>   <project>/.ai/telamon/memory/latent   — latent/ only (all .md files)
#
# Collections are registered in Telamon-managed index at
# <telamon-root>/storage/qmd/index.sqlite (XDG_CACHE_HOME override).
# Re-running this script is safe (registration is checked first).
#
# The initial `qmd embed` can take a few minutes the first time because QMD
# downloads its local GGUF models (~2 GB) on first use.

set -euo pipefail

TOOLS_PATH="${TOOLS_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${TOOLS_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "QMD vault collection"

# ── Redirect QMD cache to Telamon storage ─────────────────────────────────────────
# All qmd commands in this script run with XDG_CACHE_HOME set so the index and
# model cache live at storage/qmd/ instead of the system-wide ~/.cache/qmd/.
export XDG_CACHE_HOME="${TELAMON_ROOT}/storage"
mkdir -p "${TELAMON_ROOT}/storage/qmd"

# ── Guard: qmd must be installed ──────────────────────────────────────────────
if ! command -v qmd &>/dev/null; then
  warn "qmd not found — skipping vault collection setup"
  warn "Install with: npm install -g @tobilu/qmd"
  return 0 2>/dev/null || exit 0
fi

# ── Resolve project name from telamon.jsonc or directory basename ──────────────────
# When called from bin/init.sh we are cd'd into the project root, which has
# .ai/telamon/telamon.jsonc written in step 3.  Fall back to the directory basename.
TELAMON_INI="${PWD}/.ai/telamon/telamon.jsonc"
if [[ -f "${TELAMON_INI}" ]]; then
  PROJECT_NAME="$(config.read_ini "${TELAMON_INI}" "project_name" 2>/dev/null || true)"
else
  PROJECT_NAME="$(basename "${PWD}")"
fi

if [[ -z "${PROJECT_NAME}" ]]; then
  warn "Could not determine project name — skipping QMD collection setup"
  return 0 2>/dev/null || exit 0
fi

# Register against the latent/ path inside the project vault so only structured
# knowledge items are indexed (not work archives, thinking/, reference/, bootstrap/).
VAULT="${PWD}/.ai/telamon/memory"
BRAIN="${VAULT}/latent"

if [[ ! -d "${VAULT}" ]]; then
  warn "Vault not found at ${VAULT} — run 'make init PROJ=<path>' first"
  return 0 2>/dev/null || exit 0
fi

if [[ ! -d "${BRAIN}" ]]; then
  warn "latent/ not found at ${BRAIN} — creating empty directory"
  mkdir -p "${BRAIN}"
fi

# ── Register the single project collection ────────────────────────────────────
# `qmd collection add` is NOT idempotent: it fails if the collection already
# exists. We check first and skip if already registered.

NAME="${PROJECT_NAME}"
DESCRIPTION="latent knowledge for ${PROJECT_NAME} — memories, ADRs, PDRs, gotchas, patterns"

if qmd collection list 2>/dev/null | grep -q "^${NAME} "; then
  skip "QMD collection already registered: ${NAME}"
else
  step "Registering QMD collection: ${NAME} ..."
  qmd collection add "${BRAIN}" --name "${NAME}" --mask "**/*.md" 2>/dev/null \
    && log "Collection registered: ${NAME}" \
    || warn "qmd collection add failed for ${NAME} — retry: qmd collection add ${BRAIN} --name ${NAME} --mask '**/*.md'"
fi

step "Adding QMD context for ${NAME} ..."
qmd context add "qmd://${NAME}" "${DESCRIPTION}" 2>/dev/null || true

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

info "Brain collection registered for '${PROJECT_NAME}'."
info "Query: qmd query '<question>' -n 10"
info "Search: qmd search '<keywords>'"

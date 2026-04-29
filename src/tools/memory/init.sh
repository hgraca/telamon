#!/usr/bin/env bash
# =============================================================================
# src/tools/memory/init.sh
# Scaffold the memory vault for a project.
#
# Creates the vault directory structure, brain files (with placeholder
# substitution), bootstrap symlinks, and cross-symlinks between the project
# and Telamon storage.
#
# Expects these environment variables (set by bin/init.sh):
#   TELAMON_ROOT, TOOLS_PATH, FUNCTIONS_PATH, PROJ, PROJECT_NAME, MEMORY_OWNER
# =============================================================================

set -euo pipefail

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Memory vault scaffold"

VAULT_TMPL="${TELAMON_ROOT}/src/skills/memory/memory-management/_tmpl"

# ── Resolve vault root and symlink target ─────────────────────────────────────
if [[ "${MEMORY_OWNER}" == "project" ]]; then
  VAULT_ROOT="${PROJ}/.ai/telamon/memory"
  SYMLINK_PATH="${TELAMON_ROOT}/storage/projects-memory/${PROJECT_NAME}"
  SYMLINK_TARGET="${VAULT_ROOT}"
else
  VAULT_ROOT="${TELAMON_ROOT}/storage/projects-memory/${PROJECT_NAME}"
  SYMLINK_PATH="${PROJ}/.ai/telamon/memory"
  SYMLINK_TARGET="${VAULT_ROOT}"
fi

# ── Create directory scaffold ─────────────────────────────────────────────────
DIRS=(
  "${VAULT_ROOT}/brain"
  "${VAULT_ROOT}/work/active"
  "${VAULT_ROOT}/work/archive"
  "${VAULT_ROOT}/work/incidents"
  "${VAULT_ROOT}/reference"
  "${VAULT_ROOT}/thinking"
  "${VAULT_ROOT}/bootstrap"
  "${VAULT_ROOT}/project-rules"
)

for dir in "${DIRS[@]}"; do
  mkdir -p "${dir}"
done
log "Vault directory scaffold created"

# ── Copy brain files (with placeholder substitution) ──────────────────────────
TODAY="$(date +%Y-%m-%d)"
for tmpl_file in "${VAULT_TMPL}/brain"/*.md; do
  [[ -f "${tmpl_file}" ]] || continue
  dest="${VAULT_ROOT}/brain/$(basename "${tmpl_file}")"
  if [[ -f "${dest}" ]]; then
    skip "brain/$(basename "${tmpl_file}") (already exists)"
  else
    sed -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
        -e "s/DATE_PLACEHOLDER/${TODAY}/g" \
        "${tmpl_file}" > "${dest}"
    log "Created brain/$(basename "${tmpl_file}")"
  fi
done

# ── Bootstrap symlinks ────────────────────────────────────────────────────────
# Bootstrap files are symlinked to the template so updates propagate automatically.
for tmpl_file in "${VAULT_TMPL}/bootstrap"/*.md; do
  [[ -f "${tmpl_file}" ]] || continue
  dest="${VAULT_ROOT}/bootstrap/$(basename "${tmpl_file}")"
  if [[ -L "${dest}" || -f "${dest}" ]]; then
    skip "bootstrap/$(basename "${tmpl_file}") (already exists)"
  else
    ln -s "${tmpl_file}" "${dest}"
    log "Symlinked bootstrap/$(basename "${tmpl_file}")"
  fi
done

# ── Cross-symlink between project and Telamon storage ─────────────────────────
if [[ "${MEMORY_OWNER}" == "project" ]]; then
  # storage/projects-memory/<name> → project/.ai/telamon/memory
  mkdir -p "$(dirname "${SYMLINK_PATH}")"
  if [[ -L "${SYMLINK_PATH}" ]]; then
    skip "storage/projects-memory/${PROJECT_NAME} symlink (already exists)"
  else
    ln -s "${SYMLINK_TARGET}" "${SYMLINK_PATH}"
    log "Symlinked storage/projects-memory/${PROJECT_NAME} → .ai/telamon/memory"
  fi
else
  # project/.ai/telamon/memory → storage/projects-memory/<name>
  mkdir -p "$(dirname "${SYMLINK_PATH}")"
  if [[ -L "${SYMLINK_PATH}" ]]; then
    skip ".ai/telamon/memory symlink (already exists)"
  else
    ln -s "${SYMLINK_TARGET}" "${SYMLINK_PATH}"
    log "Symlinked .ai/telamon/memory → storage/projects-memory/${PROJECT_NAME}"
  fi
fi

info "Memory vault ready for '${PROJECT_NAME}' (${MEMORY_OWNER} mode)"

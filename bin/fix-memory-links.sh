#!/usr/bin/env bash
# =============================================================================
# bin/fix-memory-links.sh
# Fix broken .ai/telamon/memory symlinks after the vault directory was renamed
# from storage/obsidian/ to storage/projects-memory/.
#
# Usage:
#   bin/fix-memory-links.sh
#
# What it does:
#   1. Discovers all initialized projects (via storage/graphify/.project-path)
#   2. For each project, checks if .ai/telamon/memory is a broken symlink
#      pointing to the old storage/obsidian/ path
#   3. Replaces it with a symlink to the new storage/projects-memory/ path
#   4. Also fixes the reverse symlink in storage/projects-memory/ for
#      project-mode vaults
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

header "Fix memory symlinks (obsidian → projects-memory)"

FIXED=0
SKIPPED=0

# ── Strategy 1: Discover projects via graphify .project-path markers ──────────
while IFS= read -r _ppath_file; do
  [[ -f "${_ppath_file}" ]] || continue
  _proj_dir="$(cat "${_ppath_file}")"
  [[ -d "${_proj_dir}" ]] || continue

  _memory_link="${_proj_dir}/.ai/telamon/memory"

  # Case A: telamon mode — project has a symlink pointing into storage/obsidian/
  if [[ -L "${_memory_link}" ]]; then
    _target="$(readlink "${_memory_link}")"

    if [[ "${_target}" == *"/storage/obsidian/"* ]]; then
      # Replace storage/obsidian/ with storage/projects-memory/ in the target
      _new_target="${_target/storage\/obsidian\//storage\/projects-memory\/}"

      if [[ -d "${_new_target}" ]]; then
        rm "${_memory_link}"
        ln -s "${_new_target}" "${_memory_link}"
        log "Fixed: ${_proj_dir}/.ai/telamon/memory → ${_new_target}"
        FIXED=$((FIXED + 1))
      else
        warn "Target does not exist: ${_new_target} — skipping ${_proj_dir}"
        SKIPPED=$((SKIPPED + 1))
      fi
    else
      skip "${_proj_dir} (already correct or not a storage/obsidian link)"
    fi
  elif [[ -d "${_memory_link}" ]]; then
    # Case B: project mode — .ai/telamon/memory is a real directory
    # Check if the storage-side symlink is broken
    _proj_name="$(basename "${_proj_dir}")"
    _storage_link="${TELAMON_ROOT}/storage/projects-memory/${_proj_name}"

    if [[ -L "${_storage_link}" ]]; then
      skip "${_proj_dir} (project mode, storage symlink exists)"
    else
      # Check if old storage/obsidian/<name> symlink exists and needs moving
      _old_storage_link="${TELAMON_ROOT}/storage/obsidian/${_proj_name}"
      if [[ -L "${_old_storage_link}" ]]; then
        _old_target="$(readlink "${_old_storage_link}")"
        mkdir -p "${TELAMON_ROOT}/storage/projects-memory"
        ln -s "${_old_target}" "${_storage_link}"
        rm "${_old_storage_link}"
        log "Fixed storage symlink: storage/projects-memory/${_proj_name} → ${_old_target}"
        FIXED=$((FIXED + 1))
      else
        skip "${_proj_dir} (project mode, no broken link found)"
      fi
    fi
  else
    skip "${_proj_dir} (no .ai/telamon/memory link)"
  fi
done < <(find "${TELAMON_ROOT}/storage/graphify" -name ".project-path" 2>/dev/null || true)

# ── Strategy 2: Check storage/projects-memory/ entries directly ───────────────
# Some projects might not have graphify set up but still have a vault.
for _vault_dir in "${TELAMON_ROOT}/storage/projects-memory"/*/; do
  [[ -d "${_vault_dir}" ]] || continue
  _proj_name="$(basename "${_vault_dir}")"

  # Read the .project-path from codebase-index as a fallback
  _ci_proj_path="${TELAMON_ROOT}/storage/codebase-index/${_proj_name}/.project-path"
  _proj_dir=""
  if [[ -f "${_ci_proj_path}" ]]; then
    _proj_dir="$(cat "${_ci_proj_path}")"
  fi

  # If we still don't know the project path, skip
  [[ -n "${_proj_dir}" && -d "${_proj_dir}" ]] || continue

  _memory_link="${_proj_dir}/.ai/telamon/memory"
  if [[ -L "${_memory_link}" ]]; then
    _target="$(readlink "${_memory_link}")"
    if [[ "${_target}" == *"/storage/obsidian/"* ]]; then
      _new_target="${_target/storage\/obsidian\//storage\/projects-memory\/}"
      if [[ -d "${_new_target}" ]]; then
        rm "${_memory_link}"
        ln -s "${_new_target}" "${_memory_link}"
        log "Fixed: ${_proj_dir}/.ai/telamon/memory → ${_new_target}"
        FIXED=$((FIXED + 1))
      fi
    fi
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo
if [[ "${FIXED}" -gt 0 ]]; then
  echo -e "  ${TEXT_GREEN}✔  Fixed ${FIXED} symlink(s)${TEXT_CLEAR}"
else
  echo -e "  ${TEXT_DIM}–  No broken symlinks found${TEXT_CLEAR}"
fi
[[ "${SKIPPED}" -gt 0 ]] && echo -e "  ${TEXT_YELLOW}⚠  Skipped ${SKIPPED} (target not found)${TEXT_CLEAR}"
echo

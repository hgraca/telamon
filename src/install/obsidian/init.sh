#!/usr/bin/env bash
# Initialise the Obsidian memory vault for a project and create the
# <project>/.ai/telamon/memory symlink that points into it.
#
# Vault layout (telamon mode — default):
#   storage/obsidian/<project-name>/   — mirrored dir tree from src/skills/memory/memory-management/_tmpl/
#     Files with no placeholders  → symlink to _tmpl source (stays in sync)
#     Files with PROJECT_NAME / DATE_PLACEHOLDER → real copy with substitutions
#   <project>/.ai/telamon/memory           → symlink → storage/obsidian/<project-name>
#
# Vault layout (project mode):
#   <project>/.ai/telamon/memory/  — vault lives in the project
#   storage/obsidian/<project-name> → symlink → <project>/.ai/telamon/memory
#
# Expected environment (exported by bin/init.sh):
#   PROJ          — absolute path to the project root
#   PROJECT_NAME  — basename of the project
#   TELAMON_ROOT      — absolute path to Telamon repository
#   INSTALL_PATH  — absolute path to src/install/
#   MEMORY_OWNER  — 'telamon' (default) or 'project'

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TELAMON_ROOT="${TELAMON_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# Resolve project context — prefer exported vars, fall back to PWD
PROJ="${PROJ:-$(pwd)}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "${PROJ}")}"
MEMORY_OWNER="${MEMORY_OWNER:-telamon}"

VAULT_TMPL="${TELAMON_ROOT}/src/skills/memory/memory-management/_tmpl"
TODAY="$(date +%Y-%m-%d)"

header "Obsidian vault"

# ── Helper: build vault scaffold at a given root ──────────────────────────────
_build_vault_scaffold() {
  local vault_root="$1"
  local vault_label="$2"

  step "Building vault at ${vault_label} ..."
  if [[ -d "${vault_root}" ]]; then
    skip "${vault_label} (already exists)"
  else
    mkdir -p "$(dirname "${vault_root}")"

    # Walk the template tree: create real dirs, symlink or copy each file
    while IFS= read -r tmpl_file; do
      rel="${tmpl_file#"${VAULT_TMPL}/"}"       # e.g. brain/memories.md
      dest="${vault_root}/${rel}"
      dest_dir="$(dirname "${dest}")"

      mkdir -p "${dest_dir}"

      if [[ "$(basename "${tmpl_file}")" == ".gitkeep" ]]; then
        # Directory placeholder — the dir was already created; skip
        continue
      elif grep -q "PROJECT_NAME\|DATE_PLACEHOLDER" "${tmpl_file}" 2>/dev/null; then
        # File has placeholders → real copy with substitution
        cp "${tmpl_file}" "${dest}"
        os.sed_i \
          -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
          -e "s/DATE_PLACEHOLDER/${TODAY}/g" \
          "${dest}"
      else
        # No placeholders → symlink to the template source
        ln -s "${tmpl_file}" "${dest}"
      fi
    done < <(find "${VAULT_TMPL}" -type f | sort)

    log "Built ${vault_label}"
  fi
}

if [[ "${MEMORY_OWNER}" == "project" ]]; then
  # ── Project mode: vault in project, symlink in storage/ ──────────────────────
  VAULT_ROOT="${PROJ}/.ai/telamon/memory"
  STORAGE_LINK="${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}"

  mkdir -p "${PROJ}/.ai/telamon"
  _build_vault_scaffold "${VAULT_ROOT}" ".ai/telamon/memory/"

  # Create symlink storage/obsidian/<proj> → <proj>/.ai/telamon/memory
  step "Symlinking storage/obsidian/${PROJECT_NAME} → .ai/telamon/memory ..."
  if [[ -L "${STORAGE_LINK}" ]]; then
    skip "storage/obsidian/${PROJECT_NAME} symlink (already exists)"
  elif [[ -d "${STORAGE_LINK}" ]]; then
    warn "storage/obsidian/${PROJECT_NAME} is a real directory — skipping symlink creation"
  else
    mkdir -p "${TELAMON_ROOT}/storage/obsidian"
    ln -s "${VAULT_ROOT}" "${STORAGE_LINK}"
    log "Symlinked storage/obsidian/${PROJECT_NAME} → ${VAULT_ROOT}"
  fi

else
  # ── Telamon mode (default): vault in storage/, symlink in project ─────────────
  VAULT_ROOT="${TELAMON_ROOT}/storage/obsidian/${PROJECT_NAME}"
  MEMORY_LINK="${PROJ}/.ai/telamon/memory"

  _build_vault_scaffold "${VAULT_ROOT}" "storage/obsidian/${PROJECT_NAME}/"

  # Symlink <project>/.ai/telamon/memory → storage/obsidian/<project>
  step "Symlinking .ai/telamon/memory → storage/obsidian/${PROJECT_NAME} ..."
  if [[ -L "${MEMORY_LINK}" ]]; then
    skip ".ai/telamon/memory symlink (already exists)"
  elif [[ -d "${MEMORY_LINK}" ]]; then
    warn ".ai/telamon/memory is a real directory — skipping symlink creation"
  else
    mkdir -p "${PROJ}/.ai/telamon"
    ln -s "${VAULT_ROOT}" "${MEMORY_LINK}"
    log "Symlinked .ai/telamon/memory → ${VAULT_ROOT}"
  fi
fi

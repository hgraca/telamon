#!/usr/bin/env bash
# Initialise the Obsidian memory vault for a project and create the
# <project>/.ai/adk/memory symlink that points into it.
#
# Vault layout:
#   storage/obsidian/<project-name>/   — mirrored dir tree from src/skills/memory/obsidian-vault/_tmpl/
#     Files with no placeholders  → symlink to _tmpl source (stays in sync)
#     Files with PROJECT_NAME / DATE_PLACEHOLDER → real copy with substitutions
#   <project>/.ai/adk/memory           → symlink → storage/obsidian/<project-name>
#
# Expected environment (exported by bin/init.sh):
#   PROJ          — absolute path to the project root
#   PROJECT_NAME  — basename of the project
#   ADK_ROOT      — absolute path to the ADK repository
#   INSTALL_PATH  — absolute path to src/install/

set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${ADK_ROOT:-$(cd "${INSTALL_PATH}/../.." && pwd)}"
# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

# Resolve project context — prefer exported vars, fall back to PWD
PROJ="${PROJ:-$(pwd)}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "${PROJ}")}"

VAULT_ROOT="${ADK_ROOT}/storage/obsidian/${PROJECT_NAME}"
VAULT_TMPL="${ADK_ROOT}/src/skills/memory/obsidian-vault/_tmpl"
MEMORY_LINK="${PROJ}/.ai/adk/memory"
TODAY="$(date +%Y-%m-%d)"

header "Obsidian vault"

# ── Build vault scaffold ──────────────────────────────────────────────────────
step "Building vault at storage/obsidian/${PROJECT_NAME}/ ..."
if [[ -d "${VAULT_ROOT}" ]]; then
  skip "storage/obsidian/${PROJECT_NAME}/ (already exists)"
else
  mkdir -p "${ADK_ROOT}/storage/obsidian"

  # Walk the template tree: create real dirs, symlink or copy each file
  while IFS= read -r tmpl_file; do
    rel="${tmpl_file#"${VAULT_TMPL}/"}"       # e.g. brain/memories.md
    dest="${VAULT_ROOT}/${rel}"
    dest_dir="$(dirname "${dest}")"

    mkdir -p "${dest_dir}"

    if [[ "$(basename "${tmpl_file}")" == ".gitkeep" ]]; then
      # Directory placeholder — the dir was already created; skip
      continue
    elif grep -q "PROJECT_NAME\|DATE_PLACEHOLDER" "${tmpl_file}" 2>/dev/null; then
      # File has placeholders → real copy with substitution
      cp "${tmpl_file}" "${dest}"
      sed -i \
        -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
        -e "s/DATE_PLACEHOLDER/${TODAY}/g" \
        "${dest}"
    else
      # No placeholders → symlink to the template source
      ln -s "${tmpl_file}" "${dest}"
    fi
  done < <(find "${VAULT_TMPL}" -type f | sort)

  log "Built storage/obsidian/${PROJECT_NAME}/"
fi

# ── Symlink <project>/.ai/adk/memory → storage/obsidian/<project> ────────────
step "Symlinking .ai/adk/memory → storage/obsidian/${PROJECT_NAME} ..."
if [[ -L "${MEMORY_LINK}" ]]; then
  skip ".ai/adk/memory symlink (already exists)"
elif [[ -d "${MEMORY_LINK}" ]]; then
  warn ".ai/adk/memory is a real directory — skipping symlink creation"
else
  mkdir -p "${PROJ}/.ai/adk"
  ln -s "${VAULT_ROOT}" "${MEMORY_LINK}"
  log "Symlinked .ai/adk/memory → ${VAULT_ROOT}"
fi

#!/usr/bin/env bash
# =============================================================================
# bin/update.sh
# Upgrade all Telamon-managed tools to their latest versions.
# If a tool is not installed (update.sh exits 2), attempts to install it.
#
# Usage:
#   bin/update.sh
#   make update
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_PATH="${TELAMON_ROOT}/src/tools"
FUNCTIONS_PATH="${TELAMON_ROOT}/src/functions"
export TOOLS_PATH FUNCTIONS_PATH TELAMON_ROOT

# shellcheck disable=SC1091
. "${FUNCTIONS_PATH}/autoload.sh"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

echo -e "\n${TEXT_BOLD}${TEXT_BLUE}"
echo "  ╔═════════════════════════════════════════════════╗"
echo "  ║   Telamon — Harness for Agentic Software Development          ║"
echo "  ╚═════════════════════════════════════════════════╝"
echo -e "${TEXT_CLEAR}"

FAILED=0
SKIPPED=0
INSTALLED=0

# ── Telamon repo self-update ───────────────────────────────────────────────────────
header "Telamon repo"

_STASHED=0
if git -C "${TELAMON_ROOT}" diff --quiet && git -C "${TELAMON_ROOT}" diff --cached --quiet; then
  skip "stash (nothing to stash)"
else
  step "Stashing local changes..."
  git -C "${TELAMON_ROOT}" stash push --include-untracked -m "update.sh auto-stash" \
    && log "Changes stashed" \
    && _STASHED=1 \
    || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git stash failed — aborting rebase"; FAILED=$((FAILED + 1)); }
fi

if [[ "${FAILED}" -eq 0 ]]; then
  step "Rebasing onto origin..."
  git -C "${TELAMON_ROOT}" pull --rebase \
    && log "Rebased onto $(git -C "${TELAMON_ROOT}" rev-parse --abbrev-ref HEAD)" \
    || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git pull --rebase failed — resolve conflicts, then run 'git stash pop' if needed"; FAILED=$((FAILED + 1)); }
fi

if [[ "${_STASHED}" -eq 1 && "${FAILED}" -eq 0 ]]; then
  step "Restoring stashed changes..."
  git -C "${TELAMON_ROOT}" stash pop \
    && log "Stash restored" \
    || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git stash pop failed — resolve conflicts manually"; FAILED=$((FAILED + 1)); }
fi

_derive_vendor_path() {
  local url="${1%/}"
  url="${url%.git}"
  local org_repo
  if [[ "${url}" == git@* ]]; then
    org_repo="${url##*:}"
  else
    local path_part="${url#*://}"
    path_part="${path_part#*/}"
    local repo; repo="$(basename "${path_part}")"
    local org;  org="$(basename "$(dirname "${path_part}")")"
    org_repo="${org}/${repo}"
  fi
  echo "vendor/${org_repo}"
}

# ── Built-in vendor repos ─────────────────────────────────────────────────────
header "Built-in vendor repos"
BUILTIN_REPOS=(
  "https://github.com/addyosmani/agent-skills.git"
)

for _url in "${BUILTIN_REPOS[@]}"; do
  _dest="${TELAMON_ROOT}/$(_derive_vendor_path "${_url}")"
  if [[ -d "${_dest}/.git" ]]; then
    step "Pulling ${_dest} ..."
    git -C "${_dest}" pull --rebase \
      && log "Updated: ${_dest}" \
      || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git pull failed for ${_dest}"; FAILED=$((FAILED + 1)); }
  else
    step "Cloning ${_url} → ${_dest} ..."
    mkdir -p "$(dirname "${_dest}")"
    git clone --depth 1 "${_url}" "${_dest}" \
      && log "Cloned: ${_dest}" \
      || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git clone failed for ${_url}"; FAILED=$((FAILED + 1)); }
  fi
done

# ── User modules ──────────────────────────────────────────────────────────────
header "User modules"

_telamon_cfg="${TELAMON_ROOT}/.telamon.jsonc"
if [[ ! -f "${_telamon_cfg}" ]]; then
  skip "no .telamon.jsonc found"
else
  # Read module URLs (excluding built-ins and local-path modules) from .telamon.jsonc
  _user_module_lines="$(python3 - "${_telamon_cfg}" <<'PYEOF'
import json, re, sys

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

with open(sys.argv[1]) as f:
    data = json.loads(strip(f.read()))

for name, entry in data.get('modules', {}).items():
    if entry.get('builtin', False):
        continue
    if entry.get('local_path', ''):
        continue  # local modules are live directories — no git pull needed
    url = entry.get('url', '')
    if url:
        print(f'{name}\t{url}')
PYEOF
)"

  if [[ -z "${_user_module_lines}" ]]; then
    skip "no user modules configured"
  else
    while IFS=$'\t' read -r _name _url; do
      _dest="${TELAMON_ROOT}/$(_derive_vendor_path "${_url}")"
      if [[ -d "${_dest}/.git" ]]; then
        step "Pulling ${_name} ..."
        git -C "${_dest}" pull --rebase \
          && log "Updated: ${_name}" \
          || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git pull failed for ${_name}"; FAILED=$((FAILED + 1)); }
      else
        step "Cloning ${_name} (${_url}) ..."
        mkdir -p "$(dirname "${_dest}")"
        git clone --depth 1 "${_url}" "${_dest}" \
          && log "Cloned: ${_name}" \
          || { echo -e "  ${TEXT_RED}✖${TEXT_CLEAR}  git clone failed for ${_url}"; FAILED=$((FAILED + 1)); }
      fi
    done <<< "${_user_module_lines}"
  fi
fi

# ── Project config sync ───────────────────────────────────────────────────────
header "Project config sync"

# Defaults MUST match src/tools/opencode/init.sh template (step 5)
_CFG_DEFAULTS='{"rtk_enabled":true,"caveman_enabled":true,"medium_model":"","memory_owner":"telamon","discord_enabled":false,"discord_forum_channel":"","discord_forum_channel_id":""}'

while IFS= read -r _ppath_file; do
  [[ -f "${_ppath_file}" ]] || continue
  _project_dir="$(cat "${_ppath_file}")"
  _project_name="$(basename "$(dirname "${_ppath_file}")")"

  if [[ ! -d "${_project_dir}" ]]; then
    skip "${_project_name}: project directory not found (${_project_dir})"
    continue
  fi

  _cfg_file="${_project_dir}/.ai/telamon/telamon.jsonc"

  # Migrate old INI format if present
  if [[ -f "${_project_dir}/.ai/telamon/telamon.ini" && ! -f "${_cfg_file}" ]]; then
    step "${_project_name}: migrating telamon.ini → telamon.jsonc ..."
    python3 - "${_project_dir}/.ai/telamon/telamon.ini" "${_cfg_file}" <<'PYEOF'
import json, sys
ini_path = sys.argv[1]
out_path = sys.argv[2]
data = {}
with open(ini_path) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('[') or line.startswith('#') or line.startswith(';'):
            continue
        if '=' in line:
            k, v = line.split('=', 1)
            k = k.strip()
            v = v.strip()
            if v.lower() == 'true': data[k] = True
            elif v.lower() == 'false': data[k] = False
            else: data[k] = v
with open(out_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
    rm "${_project_dir}/.ai/telamon/telamon.ini"
    log "${_project_name}: migrated telamon.ini → telamon.jsonc"
  fi

  if [[ ! -f "${_cfg_file}" ]]; then
    skip "${_project_name}: no telamon.jsonc found"
    continue
  fi

  # Ensure all default keys are present
  _result="$(python3 - "${_cfg_file}" "${_CFG_DEFAULTS}" <<'PYEOF'
import json, re, sys

def strip(t): return re.sub(r'(?m)(?<!:)//.*$', '', t)

path = sys.argv[1]
defaults = json.loads(sys.argv[2])

with open(path) as f:
    data = json.loads(strip(f.read()))

added = []
for k, v in defaults.items():
    if k not in data:
        data[k] = v
        added.append(k)

if added:
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    print(', '.join(added))
PYEOF
)"

  if [[ -n "${_result}" ]]; then
    log "${_project_name}: added ${_result}"
  else
    info "${_project_name}: up to date"
  fi
done < <(find "${TELAMON_ROOT}/storage/graphify" -name ".project-path" 2>/dev/null || true)

# ── Secrets migration ─────────────────────────────────────────────────────────
header "Secrets migration"

while IFS= read -r _ppath_file; do
  [[ -f "${_ppath_file}" ]] || continue
  _project_dir="$(cat "${_ppath_file}")"
  _project_name="$(basename "$(dirname "${_ppath_file}")")"

  if [[ ! -d "${_project_dir}" ]]; then
    skip "${_project_name}: project directory not found (${_project_dir})"
    continue
  fi

  _secrets_dir="${_project_dir}/.ai/telamon/secrets"

  if [[ -L "${_secrets_dir}" ]]; then
    # Old style: secrets is a directory symlink — migrate to per-file symlinks
    rm "${_secrets_dir}"
    mkdir -p "${_secrets_dir}"
    for _secret_file in "${TELAMON_ROOT}/storage/secrets"/*; do
      [[ -f "${_secret_file}" ]] || continue
      _secret_name="$(basename "${_secret_file}")"
      ln -s "${_secret_file}" "${_secrets_dir}/${_secret_name}"
    done
    log "${_project_name}: migrated secrets from directory symlink to per-project directory"
  elif [[ -d "${_secrets_dir}" ]]; then
    # Already a real directory — add any missing secret symlinks
    _added_secrets=()
    for _secret_file in "${TELAMON_ROOT}/storage/secrets"/*; do
      [[ -f "${_secret_file}" ]] || continue
      _secret_name="$(basename "${_secret_file}")"
      if [[ ! -e "${_secrets_dir}/${_secret_name}" ]]; then
        ln -s "${_secret_file}" "${_secrets_dir}/${_secret_name}"
        _added_secrets+=("${_secret_name}")
      fi
    done
    if [[ "${#_added_secrets[@]}" -gt 0 ]]; then
      log "${_project_name}: added ${#_added_secrets[@]} missing secret symlink(s): $(IFS=', '; echo "${_added_secrets[*]}")"
    else
      info "${_project_name}: secrets up to date"
    fi
  else
    skip "${_project_name}: no secrets directory"
    continue
  fi
done < <(find "${TELAMON_ROOT}/storage/graphify" -name ".project-path" 2>/dev/null || true)

# ── Codebase-index config migration ───────────────────────────────────────────
header "Codebase-index config migration"

while IFS= read -r _ppath_file; do
  [[ -f "${_ppath_file}" ]] || continue
  _project_dir="$(cat "${_ppath_file}")"
  _project_name="$(basename "$(dirname "${_ppath_file}")")"

  if [[ ! -d "${_project_dir}" ]]; then
    skip "${_project_name}: project directory not found (${_project_dir})"
    continue
  fi

  _index_config="${_project_dir}/.opencode/codebase-index.json"

  if [[ ! -f "${_index_config}" ]]; then
    skip "${_project_name}: no codebase-index config"
    continue
  fi

  if grep -q '"embeddingProvider": "ollama"' "${_index_config}"; then
    python3 -c "
import json, sys
with open(sys.argv[1], 'r') as f:
    cfg = json.load(f)
cfg['embeddingProvider'] = 'custom'
cfg['customProvider'] = {
    'baseUrl': 'http://127.0.0.1:17434/v1',
    'model': 'nomic-embed-text',
    'dimensions': 768,
    'apiKey': 'ollama'
}
with open(sys.argv[1], 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
" "${_index_config}"
    log "${_project_name}: migrated codebase-index from ollama to custom provider (port 17434)"
  else
    info "${_project_name}: codebase-index config up to date"
  fi
done < <(find "${TELAMON_ROOT}/storage/graphify" -name ".project-path" 2>/dev/null || true)

# ── Per-app updates ────────────────────────────────────────────────────────────
# Each src/tools/<app>/update.sh exits:
#   0 — success
#   1 — failure
#   2 — tool not installed → fall through to install.sh
UPDATE_APPS=(homebrew docker opencode graphify codebase-index caveman rtk nodejs qmd repomix promptfoo discord)

for _app in "${UPDATE_APPS[@]}"; do
  _script="${TOOLS_PATH}/${_app}/update.sh"
  if [[ ! -f "${_script}" ]]; then
    warn "No update.sh for ${_app} — skipping"
    continue
  fi
  timed_run "${_app}" bash "${_script}" && true   # suppress errexit for exit-code capture
  _rc=$?
  case "${_rc}" in
    0) : ;;                               # success — nothing to tally
    2)                                     # not installed — attempt install
      _install_script="${TOOLS_PATH}/${_app}/install.sh"
      if [[ -f "${_install_script}" ]]; then
        step "Installing missing tool: ${_app} ..."
        timed_run "${_app}" bash "${_install_script}" && true
        _irc=$?
        if [[ "${_irc}" -ne 0 ]]; then
          FAILED=$((FAILED + 1))
        else
          INSTALLED=$((INSTALLED + 1))
        fi
      else
        SKIPPED=$((SKIPPED + 1))
      fi
      ;;
    *) FAILED=$((FAILED + 1)) ;;         # any other non-zero = failure
  esac
done

# ── Cass migration ─────────────────────────────────────────────────────────────
# Cass was removed from Telamon. If still installed, offer to uninstall it.
if command -v cass &>/dev/null; then
  echo
  header "Cass (deprecated)"
  warn "cass is installed but is no longer part of Telamon."
  ask "Remove cass from this system? (Y/n):"
  read -r _cass_confirm
  if [[ ! "${_cass_confirm}" =~ ^[Nn] ]]; then
    step "Removing cass-index scheduled jobs..."
    if [[ -f "${TOOLS_PATH}/cass/schedule.sh" ]]; then
      bash "${TOOLS_PATH}/cass/schedule.sh" --remove 2>/dev/null || true
    fi
    _cass_os="$(uname -s)"
    if [[ "${_cass_os}" == "Linux" ]]; then
      for _timer in "${HOME}/.config/systemd/user"/cass-index-*.timer; do
        [[ -f "${_timer}" ]] || continue
        _tname="$(basename "${_timer}" .timer)"
        systemctl --user disable --now "${_tname}.timer" 2>/dev/null || true
        rm -f "${HOME}/.config/systemd/user/${_tname}.service" "${HOME}/.config/systemd/user/${_tname}.timer"
      done
      systemctl --user daemon-reload 2>/dev/null || true
    elif [[ "${_cass_os}" == "Darwin" ]]; then
      for _plist in "${HOME}/Library/LaunchAgents"/com.telamon.cass-index-*.plist; do
        [[ -f "${_plist}" ]] || continue
        launchctl bootout "gui/$(id -u)" "${_plist}" 2>/dev/null || true
        rm -f "${_plist}"
      done
    fi
    log "Scheduled jobs removed"

    step "Uninstalling cass via Homebrew..."
    if command -v brew &>/dev/null; then
      brew uninstall cass 2>/dev/null || true
      brew untap dicklesworthstone/tap 2>/dev/null || true
    fi
    log "cass uninstalled"

    # Remove skill file if still present
    _cass_skill="${TELAMON_ROOT}/src/skills/memory/_tools/cass"
    if [[ -d "${_cass_skill}" ]]; then
      rm -rf "${_cass_skill}"
      log "Removed cass skill"
    fi
  else
    info "Keeping cass installed — you can remove it manually later with: brew uninstall cass"
  fi
fi

# ── Vault directory migration: storage/obsidian/ → storage/projects-memory/ ───
# The vault was previously stored under storage/obsidian/. Rename silently.
_OLD_VAULT_DIR="${TELAMON_ROOT}/storage/obsidian"
_NEW_VAULT_DIR="${TELAMON_ROOT}/storage/projects-memory"
_VAULT_MIGRATED=0
if [[ -d "${_OLD_VAULT_DIR}" && ! -d "${_NEW_VAULT_DIR}" ]]; then
  step "Migrating vault directory: storage/obsidian/ → storage/projects-memory/ ..."
  mv "${_OLD_VAULT_DIR}" "${_NEW_VAULT_DIR}"
  log "Vault directory renamed"
  _VAULT_MIGRATED=1
elif [[ -d "${_OLD_VAULT_DIR}" && -d "${_NEW_VAULT_DIR}" ]]; then
  # Both exist — merge projects from old into new
  step "Merging remaining projects from storage/obsidian/ into storage/projects-memory/ ..."
  for _proj_dir in "${_OLD_VAULT_DIR}"/*/; do
    [[ -d "${_proj_dir}" ]] || continue
    _pname="$(basename "${_proj_dir}")"
    if [[ ! -e "${_NEW_VAULT_DIR}/${_pname}" ]]; then
      mv "${_proj_dir}" "${_NEW_VAULT_DIR}/${_pname}"
      log "Moved ${_pname}"
    fi
  done
  # Remove old directory if empty
  rmdir "${_OLD_VAULT_DIR}" 2>/dev/null && log "Removed empty storage/obsidian/" || true
  _VAULT_MIGRATED=1
fi

# Fix broken symlinks in external projects after the directory rename
if [[ "${_VAULT_MIGRATED}" -eq 1 ]]; then
  bash "${TELAMON_ROOT}/bin/fix-memory-links.sh"
fi

# ── Always repair stale .ai/telamon/memory symlinks ───────────────────────────
# Even if the vault directory was already migrated in a previous run, external
# projects may still have stale symlinks pointing to storage/obsidian/.
# Scan all known projects and fix any that still point to the old path.
_fix_memory_link() {
  local _link="$1"
  local _proj_name="$2"
  [[ -L "${_link}" ]] || return 0
  local _target
  _target="$(readlink "${_link}")"
  if [[ "${_target}" == *"/storage/obsidian/"* ]]; then
    local _new_target="${_target/storage\/obsidian\//storage\/projects-memory\/}"
    if [[ -d "${_new_target}" ]]; then
      rm "${_link}"
      ln -s "${_new_target}" "${_link}"
      log "Fixed .ai/telamon/memory symlink (${_proj_name})"
    fi
  fi
}

# Fix Telamon's own memory link
_fix_memory_link "${TELAMON_ROOT}/.ai/telamon/memory" "telamon"

# Fix all initialized projects discovered via graphify storage
for _storage_dir in "${TELAMON_ROOT}/storage/graphify"/*/; do
  [[ -d "${_storage_dir}" ]] || continue
  [[ -f "${_storage_dir}.project-path" ]] || continue
  _proj_dir="$(cat "${_storage_dir}.project-path")"
  [[ -d "${_proj_dir}" ]] || continue
  _fix_memory_link "${_proj_dir}/.ai/telamon/memory" "$(basename "${_proj_dir}")"
done

# Also check via codebase-index storage (projects without graphify)
for _storage_dir in "${TELAMON_ROOT}/storage/codebase-index"/*/; do
  [[ -d "${_storage_dir}" ]] || continue
  [[ -f "${_storage_dir}.project-path" ]] || continue
  _proj_dir="$(cat "${_storage_dir}.project-path")"
  [[ -d "${_proj_dir}" ]] || continue
  _fix_memory_link "${_proj_dir}/.ai/telamon/memory" "$(basename "${_proj_dir}")"
done

# ── Obsidian migration ─────────────────────────────────────────────────────────
# Obsidian MCP was removed from Telamon. The knowledge vault is now managed
# directly as plain markdown files with QMD for semantic search.
# If Obsidian is still installed, offer to clean up.
_obsidian_installed=0
if command -v obsidian &>/dev/null; then
  _obsidian_installed=1
elif [[ "$(uname -s)" == "Darwin" ]] && [[ -d "/Applications/Obsidian.app" ]]; then
  _obsidian_installed=1
fi

if [[ "${_obsidian_installed}" -eq 1 ]]; then
  echo
  header "Obsidian (no longer used)"
  warn "Obsidian is installed but Telamon no longer uses it."
  info "The knowledge vault is now managed as plain markdown files."
  info "QMD provides semantic search; the agent reads/writes notes directly."
  echo
  ask "Uninstall Obsidian from this system? (y/N):"
  read -r _obs_confirm
  if [[ "${_obs_confirm}" =~ ^[Yy] ]]; then
    _obs_os="$(uname -s)"
    if [[ "${_obs_os}" == "Darwin" ]]; then
      step "Uninstalling Obsidian via Homebrew cask..."
      if command -v brew &>/dev/null && brew list --cask obsidian &>/dev/null 2>&1; then
        brew uninstall --cask obsidian 2>/dev/null || true
        log "Obsidian cask uninstalled"
      elif [[ -d "/Applications/Obsidian.app" ]]; then
        rm -rf "/Applications/Obsidian.app"
        log "Obsidian.app removed from /Applications"
      else
        skip "Obsidian not found via brew cask or /Applications"
      fi
    else
      step "Uninstalling Obsidian..."
      if command -v dpkg &>/dev/null && dpkg -l obsidian &>/dev/null 2>&1; then
        sudo dpkg --remove obsidian 2>/dev/null || sudo apt-get remove -y obsidian 2>/dev/null || true
        log "Obsidian .deb package removed"
      elif command -v flatpak &>/dev/null && flatpak list --app | grep -qi obsidian; then
        flatpak uninstall -y md.obsidian.Obsidian 2>/dev/null || true
        log "Obsidian flatpak removed"
      else
        warn "Could not determine how Obsidian was installed — remove it manually"
      fi
      # Always remove CLI tool (may exist independently of package install)
      if [[ -f "$HOME/.local/bin/obsidian" ]]; then
        rm -f "$HOME/.local/bin/obsidian"
        log "Obsidian CLI removed from ~/.local/bin"
      fi
    fi

    # Remove Docker MCP image if present
    if docker image inspect oleksandrkucherenko/obsidian-mcp:latest &>/dev/null 2>&1; then
      step "Removing Obsidian MCP Docker image..."
      docker rmi oleksandrkucherenko/obsidian-mcp:latest 2>/dev/null || true
      log "Obsidian MCP Docker image removed"
    fi

    # Remove stale secret file
    _obs_secret="${TELAMON_ROOT}/storage/secrets/obsidian-api-key"
    if [[ -f "${_obs_secret}" ]]; then
      rm -f "${_obs_secret}"
      log "Removed storage/secrets/obsidian-api-key"
    fi

    log "Obsidian cleanup complete"
  else
    info "Keeping Obsidian installed — it is no longer used by Telamon but won't interfere."
  fi
fi

# ── Brain file migration: key_decisions.md → PDRs.md + ADRs.md ────────────────
# key_decisions.md was split into PDRs.md (product decisions) and ADRs.md
# (architecture/technical decisions). Rename existing file to PDRs.md and
# create ADRs.md if missing.
for _brain_dir in "${TELAMON_ROOT}/storage/projects-memory"/*/brain; do
  [[ -d "${_brain_dir}" ]] || continue
  _project_name="$(basename "$(dirname "${_brain_dir}")")"

  if [[ -f "${_brain_dir}/key_decisions.md" ]]; then
    mv "${_brain_dir}/key_decisions.md" "${_brain_dir}/PDRs.md"
    log "${_project_name}: renamed brain/key_decisions.md → brain/PDRs.md"
    echo
    info "  ⚠  brain/PDRs.md may contain architecture decisions that belong in brain/ADRs.md."
    info "     Ask Telamon: \"Split architecture decisions from PDRs.md into ADRs.md\""
    echo
  fi

  if [[ ! -f "${_brain_dir}/ADRs.md" ]]; then
    _today="$(date +%Y-%m-%d)"
    cat > "${_brain_dir}/ADRs.md" <<EOF
---
date: ${_today}
description: Architecture and technical decisions for ${_project_name}
tags: [brain, decisions, architecture]
status: active
---

# Architecture Decisions — ${_project_name}

<!-- Format: ## Decision title
Date: YYYY-MM-DD
Decision: what was decided
Rationale: why
Alternatives considered: what else was considered
-->

## See also

- [[PDRs]]
- [[memories]]
- [[patterns]]
- [[gotchas]]
EOF
    log "${_project_name}: created brain/ADRs.md"
  fi
done

# ── Summary ────────────────────────────────────────────────────────────────────
echo
echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
echo -e "${TEXT_BOLD}  Update complete${TEXT_CLEAR}"
echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
echo
[[ "${INSTALLED}" -gt 0 ]] && echo -e "  ${TEXT_GREEN}+  Installed ${INSTALLED} missing tool(s)${TEXT_CLEAR}"
[[ "${SKIPPED}"  -gt 0 ]] && echo -e "  ${TEXT_DIM}–  Skipped ${SKIPPED} tool(s) (no install.sh available)${TEXT_CLEAR}"
[[ "${FAILED}"   -gt 0 ]] && echo -e "  ${TEXT_RED}✖  ${FAILED} upgrade(s) failed — see above for details${TEXT_CLEAR}"
[[ "${FAILED}"   -eq 0 ]] && echo -e "  ${TEXT_GREEN}✔  All tools are up to date${TEXT_CLEAR}"
echo -e "  ${TEXT_DIM}⏱  Total update time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"
echo

[[ "${FAILED}" -gt 0 ]] && exit 1 || exit 0

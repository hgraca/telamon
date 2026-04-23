#!/usr/bin/env bash
# =============================================================================
# bin/update.sh
# Upgrade all Telamon-managed tools to their latest versions.
#
# Usage:
#   bin/update.sh
#   make update
# =============================================================================

set -euo pipefail

TELAMON_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_PATH="${TELAMON_ROOT}/src/install"
export INSTALL_PATH TELAMON_ROOT

# shellcheck disable=SC1091
. "${INSTALL_PATH}/functions/autoload.sh"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

echo -e "\n${TEXT_BOLD}${TEXT_BLUE}"
echo "  ╔═════════════════════════════════════════════════╗"
echo "  ║   Telamon — Harness for Agentic Software Development          ║"
echo "  ╚═════════════════════════════════════════════════╝"
echo -e "${TEXT_CLEAR}"

FAILED=0
SKIPPED=0

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

# ── User submodules ───────────────────────────────────────────────────────────
header "User submodules"

_raw_submodules="$(grep -s '^TELAMON_SUBMODULES=' "${TELAMON_ROOT}/.env" | head -1 | cut -d= -f2- | tr -d "\"'" || true)"

if [[ -z "${_raw_submodules}" ]]; then
  skip "no user submodules configured"
else
  IFS=',' read -ra _user_repos <<< "${_raw_submodules}"
  for _url in "${_user_repos[@]}"; do
    _url="${_url// /}"
    [[ -z "${_url}" ]] && continue
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
fi

# ── Project config sync ───────────────────────────────────────────────────────
header "Project config sync"

# Defaults MUST match src/install/opencode/init.sh template (step 5)
_INI_DEFAULTS=(
  "rtk_enabled=false"
  "caveman_enabled=false"
  "medium_model="
  "memory_owner=telamon"
  "ogham_db=telamon"
)

while IFS= read -r _ppath_file; do
  [[ -f "${_ppath_file}" ]] || continue
  _project_dir="$(cat "${_ppath_file}")"
  _project_name="$(basename "$(dirname "${_ppath_file}")")"

  if [[ ! -d "${_project_dir}" ]]; then
    skip "${_project_name}: project directory not found (${_project_dir})"
    continue
  fi

  _ini_file="${_project_dir}/.ai/telamon/telamon.ini"
  if [[ ! -f "${_ini_file}" ]]; then
    skip "${_project_name}: no telamon.ini found"
    continue
  fi

  _added=()
  for _pair in "${_INI_DEFAULTS[@]}"; do
    _key="${_pair%%=*}"
    _default="${_pair#*=}"
    if ! grep -qE "^[[:space:]]*${_key}[[:space:]]*=" "${_ini_file}"; then
      echo "${_key} = ${_default}" >> "${_ini_file}"
      _added+=("${_key}")
    fi
  done

  if [[ "${#_added[@]}" -gt 0 ]]; then
    log "${_project_name}: added $(IFS=', '; echo "${_added[*]}")"
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
# Each src/install/<app>/update.sh exits:
#   0 — success
#   1 — failure
#   2 — tool not installed (skip)
UPDATE_APPS=(homebrew docker opencode ogham graphify caveman rtk nodejs qmd repomix promptfoo)

for _app in "${UPDATE_APPS[@]}"; do
  _script="${INSTALL_PATH}/${_app}/update.sh"
  if [[ ! -f "${_script}" ]]; then
    warn "No update.sh for ${_app} — skipping"
    continue
  fi
  timed_run "${_app}" bash "${_script}" && true   # suppress errexit for exit-code capture
  _rc=$?
  case "${_rc}" in
    0) : ;;                               # success — nothing to tally
    2) SKIPPED=$((SKIPPED + 1)) ;;       # not installed
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
    if [[ -f "${INSTALL_PATH}/cass/schedule.sh" ]]; then
      bash "${INSTALL_PATH}/cass/schedule.sh" --remove 2>/dev/null || true
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

# ── Summary ────────────────────────────────────────────────────────────────────
echo
echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
echo -e "${TEXT_BOLD}  Update complete${TEXT_CLEAR}"
echo -e "${TEXT_BOLD}${TEXT_GREEN}══════════════════════════════════════════${TEXT_CLEAR}"
echo
[[ "${SKIPPED}" -gt 0 ]] && echo -e "  ${TEXT_DIM}–  Skipped ${SKIPPED} tool(s) not installed on this machine${TEXT_CLEAR}"
[[ "${FAILED}"  -gt 0 ]] && echo -e "  ${TEXT_RED}✖  ${FAILED} upgrade(s) failed — see above for details${TEXT_CLEAR}"
[[ "${FAILED}"  -eq 0 ]] && echo -e "  ${TEXT_GREEN}✔  All installed tools are up to date${TEXT_CLEAR}"
echo -e "  ${TEXT_DIM}⏱  Total update time: $(_fmt_duration ${SECONDS})${TEXT_CLEAR}"
echo

[[ "${FAILED}" -gt 0 ]] && exit 1 || exit 0
